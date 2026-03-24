defmodule Gallformers.Storage do
  @moduledoc """
  S3 storage operations.

  Top-level shared infrastructure for all S3 interactions including uploads,
  deletions, presigned URLs, size variant generation, and bucket listing operations.
  """
  use Boundary, deps: [Gallformers.S3, Gallformers.Async], exports: :all

  require Logger

  # Image processing library (vix-based)
  alias Image, as: ImageLib

  # Image sizes for resizing (width in pixels)
  @sizes %{
    small: 300,
    medium: 800,
    large: 1200,
    xlarge: 2000
  }

  # =============================================================================
  # Configuration
  # =============================================================================

  @doc """
  Returns the CDN base URL for images.
  """
  @spec cdn_url() :: String.t()
  def cdn_url do
    Application.get_env(:gallformers, :images)[:cdn_url]
  end

  @doc """
  Returns the S3 bucket name.
  """
  @spec bucket() :: String.t()
  def bucket do
    Application.get_env(:gallformers, :images)[:bucket]
  end

  @doc """
  Returns the S3 image prefix for preview deploys.

  When set (e.g., "preview"), new uploads go to "preview/gall/..." instead of "gall/...".
  Returns nil in production (no prefix).
  """
  @spec s3_image_prefix() :: String.t() | nil
  def s3_image_prefix do
    Application.get_env(:gallformers, :s3_image_prefix)
  end

  # Prepends the S3 image prefix to a path when configured.
  # Used for new uploads only — existing DB paths are not prefixed.
  defp prefix_path(path) do
    case s3_image_prefix() do
      nil -> path
      "" -> path
      prefix -> "#{prefix}/#{path}"
    end
  end

  # =============================================================================
  # Path Generation
  # =============================================================================

  @doc """
  Generates the S3 path for a species image.

  Format: gall/{species_id}/{species_id}_{timestamp}_{unique}_original.{ext}
  """
  @spec generate_path(integer(), String.t()) :: String.t()
  def generate_path(species_id, extension) do
    timestamp = System.system_time(:millisecond)
    unique = System.unique_integer([:positive])
    ext = String.trim_leading(extension, ".")
    prefix_path("gall/#{species_id}/#{species_id}_#{timestamp}_#{unique}_original.#{ext}")
  end

  @doc """
  Generates the S3 path for an article image.

  Format: articles/{article_id}/{timestamp}.{ext}

  Uses article ID instead of slug since slugs can change but IDs are stable.
  """
  @spec generate_article_path(integer(), String.t()) :: String.t()
  def generate_article_path(article_id, extension) when is_integer(article_id) do
    timestamp = System.system_time(:millisecond)
    ext = String.trim_leading(extension, ".")
    prefix_path("articles/#{article_id}/#{timestamp}.#{ext}")
  end

  @doc """
  Generates the S3 path for a content image (article or key).

  Options:
  - `has_variants` - when true, includes `_original` suffix for size variant generation

  Format with variants: {prefix}/{owner_id}/{ts}_{unique}_original.{ext}
  Format without:       {prefix}/{owner_id}/{ts}_{unique}.{ext}
  """
  @spec generate_content_image_path(String.t(), integer(), String.t(), keyword()) :: String.t()
  def generate_content_image_path(prefix, owner_id, extension, opts \\ []) do
    timestamp = System.system_time(:millisecond)
    unique = System.unique_integer([:positive])
    ext = String.trim_leading(extension, ".")
    has_variants = Keyword.get(opts, :has_variants, false)

    filename =
      if has_variants,
        do: "#{timestamp}_#{unique}_original.#{ext}",
        else: "#{timestamp}_#{unique}.#{ext}"

    prefix_path("#{prefix}/#{owner_id}/#{filename}")
  end

  @doc """
  Returns the full CDN URL for an article image path.
  """
  @spec article_image_url(String.t()) :: String.t()
  def article_image_url(path) do
    "#{cdn_url()}/#{path}"
  end

  # =============================================================================
  # Upload Operations
  # =============================================================================

  @doc """
  Generates a presigned URL for uploading an image to S3.

  Returns {:ok, presigned_url} or {:error, reason}.
  """
  @spec presigned_upload_url(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def presigned_upload_url(path, content_type) do
    expiry = Application.get_env(:gallformers, :images)[:presign_expiry] || 300

    config = ExAws.Config.new(:s3)

    case ExAws.S3.presigned_url(config, :put, bucket(), path,
           expires_in: expiry,
           query_params: [{"Content-Type", content_type}]
         ) do
      {:ok, url} -> {:ok, url}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Uploads data to S3.
  """
  @spec upload(String.t(), binary(), String.t()) :: {:ok, term()} | {:error, term()}
  def upload(path, data, content_type) do
    ExAws.S3.put_object(bucket(), path, data,
      content_type: content_type
      # Note: No ACL needed - bucket has public read policy
    )
    |> Gallformers.S3.request()
  end

  # =============================================================================
  # Size Variant Generation
  # =============================================================================

  @doc """
  Generates image size variants and uploads them to S3.

  This is called after the original image has been uploaded.
  The function downloads the original, resizes it, and uploads
  the variants asynchronously.
  """
  @spec generate_size_variants(String.t()) :: :ok | {:error, term()}
  def generate_size_variants(original_path) do
    generate_size_variants(original_path, @sizes)
  end

  @doc """
  Generates image size variants with a custom sizes config.

  `sizes` is a map or keyword list of `{name, width_px}` pairs.
  An empty map/list is a no-op.
  """
  @spec generate_size_variants(String.t(), map() | keyword()) :: :ok | {:error, term()}
  def generate_size_variants(_original_path, sizes) when sizes == %{} or sizes == [] do
    :ok
  end

  def generate_size_variants(original_path, sizes) do
    original_url = cdn_url() <> "/" <> original_path

    case fetch_original_image(original_url) do
      {:ok, body} ->
        spawn_resize_tasks(body, original_path, sizes)
        :ok

      {:error, reason} ->
        Logger.error("Failed to generate size variants for #{original_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_original_image(url) do
    case Req.get(url) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, {:fetch_failed, status}}
      {:error, reason} -> {:error, {:fetch_failed, reason}}
    end
  end

  defp spawn_resize_tasks(body, original_path, sizes) do
    Enum.each(sizes, fn {size_name, width} ->
      Gallformers.Async.run(fn -> resize_and_upload(body, original_path, size_name, width) end)
    end)
  end

  defp resize_and_upload(image_data, original_path, size_name, target_width) do
    size_str = Atom.to_string(size_name)
    new_path = String.replace(original_path, "original", size_str)
    format = get_image_format(original_path)
    content_type = format_to_content_type(format)

    with {:ok, img} <- ImageLib.open(image_data),
         {:ok, resized} <- ImageLib.thumbnail(img, target_width),
         {:ok, output_data} <- ImageLib.write(resized, :memory, suffix: ".#{format}"),
         {:ok, _response} <- upload(new_path, output_data, content_type) do
      {:ok, new_path}
    else
      {:error, reason} ->
        Logger.error(
          "Failed to process #{size_name} variant for #{original_path}: #{inspect(reason)}"
        )

        {:error, {:resize_failed, reason}}
    end
  end

  defp get_image_format(path) do
    if String.ends_with?(path, ".png"), do: :png, else: :jpeg
  end

  defp format_to_content_type(:png), do: "image/png"
  defp format_to_content_type(:jpeg), do: "image/jpeg"

  # =============================================================================
  # Delete Operations
  # =============================================================================

  @doc """
  Returns the list of S3 keys for a content image path and its size variants.

  For paths without variants (empty sizes list), returns just the original path.
  For paths with variants, returns original + each variant key.
  """
  @spec variant_keys_for_path(String.t(), [atom()]) :: [String.t()]
  def variant_keys_for_path(path, []), do: [path]

  def variant_keys_for_path(path, sizes) do
    variant_keys =
      Enum.map(sizes, fn size_name ->
        String.replace(path, "original", Atom.to_string(size_name))
      end)

    [path | variant_keys]
  end

  @doc """
  Deletes a content image and its size variants from S3.

  Pass an empty sizes list for images without variants (articles).
  Pass the variant size names for images with variants (keys).
  """
  @spec delete_content_image(String.t(), [atom()]) :: :ok | {:error, term()}
  def delete_content_image(path, sizes) when is_binary(path) do
    keys = variant_keys_for_path(path, sizes)

    case ExAws.S3.delete_multiple_objects(bucket(), keys) |> Gallformers.S3.request() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Deletes an image and all its size variants from S3.

  Deletes all size variants (original, small, medium, large, xlarge).
  """
  @spec delete_image(String.t()) :: :ok | {:error, term()}
  def delete_image(path) when is_binary(path) do
    # Generate all size variant keys
    keys =
      [:original, :small, :medium, :large, :xlarge]
      |> Enum.map(fn size ->
        size_str = Atom.to_string(size)
        String.replace(path, "original", size_str)
      end)

    # Delete all variants
    case ExAws.S3.delete_multiple_objects(bucket(), keys) |> Gallformers.S3.request() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_image(_), do: :ok

  @doc """
  Deletes an article image from S3.

  Takes the full S3 path (e.g., "articles/123/1234567890.jpg").
  Returns :ok on success or {:error, reason} on failure.
  """
  @spec delete_article_image(String.t()) :: :ok | {:error, term()}
  def delete_article_image(path) when is_binary(path) do
    Logger.info("Attempting to delete article image: #{path} from bucket: #{bucket()}")

    case ExAws.S3.delete_object(bucket(), path) |> Gallformers.S3.request() do
      {:ok, _} ->
        Logger.info("Successfully deleted article image: #{path}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete article image: #{path}, reason: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # =============================================================================
  # Listing Operations
  # =============================================================================

  @doc """
  Lists all images in the articles folder on S3.

  Returns a list of maps with :path, :url, :name, :folder, and :article_id keys.
  """
  @spec list_article_images() :: [map()]
  def list_article_images do
    list_article_images_with_prefix(prefix_path("articles/"))
  end

  @doc """
  Lists images for a specific article by ID.
  """
  @spec list_article_images_for_article(integer()) :: [map()]
  def list_article_images_for_article(article_id) do
    list_article_images_with_prefix(prefix_path("articles/#{article_id}/"))
  end

  defp list_article_images_with_prefix(prefix) do
    case ExAws.S3.list_objects(bucket(), prefix: prefix) |> Gallformers.S3.request() do
      {:ok, %{body: body}} ->
        # contents may be missing, nil, or a list depending on S3 response
        contents = Map.get(body, :contents) || []
        contents = if is_list(contents), do: contents, else: []

        contents
        |> Enum.filter(&image_file?/1)
        |> Enum.map(&transform_article_s3_object/1)
        |> Enum.sort_by(& &1.last_modified, :desc)

      {:error, reason} ->
        Logger.warning("Failed to list article images: #{inspect(reason)}")
        []
    end
  end

  defp image_file?(obj) do
    String.ends_with?(obj.key, [".jpg", ".jpeg", ".png", ".gif", ".webp"])
  end

  defp transform_article_s3_object(obj) do
    path = obj.key
    parts = String.split(path, "/")
    folder = extract_folder(parts)

    %{
      path: path,
      url: article_image_url(path),
      name: List.last(parts),
      folder: folder,
      article_id: parse_article_id(folder),
      last_modified: obj.last_modified,
      size: obj.size
    }
  end

  defp extract_folder(parts) when length(parts) >= 2, do: Enum.at(parts, 1)
  defp extract_folder(_parts), do: ""

  defp parse_article_id(folder) do
    case Integer.parse(folder) do
      {id, ""} -> id
      _ -> nil
    end
  end

  @doc """
  Lists all image paths from S3 under the gall/ prefix.

  Returns a list of S3 object maps with :key, :last_modified, and :size.
  This can be slow for large buckets - consider using the AuditCache for cached results.
  """
  @spec list_all_gall_paths() :: {:ok, [map()]} | {:error, term()}
  def list_all_gall_paths do
    if Application.get_env(:gallformers, :s3_enabled, true) do
      list_gall_paths_recursive(prefix_path("gall/"), nil, [])
    else
      # Return empty list in test environment to avoid real S3 calls
      {:ok, []}
    end
  end

  defp list_gall_paths_recursive(prefix, continuation_token, acc) do
    opts =
      [prefix: prefix]
      |> maybe_add_continuation_token(continuation_token)

    case ExAws.S3.list_objects_v2(bucket(), opts) |> Gallformers.S3.request() do
      {:ok, %{body: body}} ->
        contents = body[:contents] || []
        # Filter to only original images (not size variants)
        new_paths =
          contents
          |> Enum.filter(&original_gall_image?/1)
          |> Enum.map(&extract_s3_object_info/1)

        all_paths = new_paths ++ acc

        # Check for more pages
        if body[:is_truncated] == "true" && body[:next_continuation_token] do
          list_gall_paths_recursive(prefix, body[:next_continuation_token], all_paths)
        else
          {:ok, all_paths}
        end

      {:error, reason} ->
        Logger.error("Failed to list S3 gall paths: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp maybe_add_continuation_token(opts, nil), do: opts

  defp maybe_add_continuation_token(opts, token),
    do: Keyword.put(opts, :continuation_token, token)

  defp original_gall_image?(obj) do
    String.contains?(obj[:key], "_original.") && image_extension?(obj[:key])
  end

  defp image_extension?(path) do
    String.ends_with?(path, [".jpg", ".jpeg", ".png", ".gif", ".webp"])
  end

  defp extract_s3_object_info(obj) do
    %{
      key: obj[:key],
      last_modified: obj[:last_modified],
      size: obj[:size]
    }
  end
end
