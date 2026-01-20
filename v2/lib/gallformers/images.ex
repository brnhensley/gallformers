defmodule Gallformers.Images do
  @moduledoc """
  The Images context.

  Provides functions for managing species images including S3 uploads,
  presigned URLs, image processing, and database operations.
  """

  require Logger

  import Ecto.Query
  alias Gallformers.Repo
  alias Gallformers.Species.Image, as: ImageSchema
  alias Gallformers.Species.Species

  # Image processing library (vix-based)
  alias Image, as: ImageLib

  # Image sizes for resizing (width in pixels)
  @sizes %{
    small: 300,
    medium: 800,
    large: 1200,
    xlarge: 2000
  }

  # Accepted MIME types for upload
  @accepted_types ~w(image/jpeg image/png image/jpg)

  @doc """
  Returns the list of accepted MIME types for image upload.
  """
  @spec accepted_types() :: [String.t()]
  def accepted_types, do: @accepted_types

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
  Generates the S3 path for an image.

  Format: gall/{species_id}/{species_id}_{timestamp}_original.{ext}
  """
  @spec generate_path(integer(), String.t()) :: String.t()
  def generate_path(species_id, extension) do
    timestamp = System.system_time(:millisecond)
    ext = String.trim_leading(extension, ".")
    "gall/#{species_id}/#{species_id}_#{timestamp}_original.#{ext}"
  end

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
  Gets all images for a species, ordered with default first.
  """
  @spec list_images_for_species(integer()) :: [ImageSchema.t()]
  def list_images_for_species(species_id) do
    from(i in ImageSchema,
      left_join: src in assoc(i, :source),
      where: i.species_id == ^species_id,
      order_by: [desc: i.default, asc: i.id],
      preload: [source: src]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single image by ID.
  """
  @spec get_image(integer()) :: ImageSchema.t() | nil
  def get_image(id) do
    Repo.get(ImageSchema, id) |> Repo.preload(:source)
  end

  @doc """
  Gets a single image by ID, raising if not found.
  """
  @spec get_image!(integer()) :: ImageSchema.t()
  def get_image!(id) do
    Repo.get!(ImageSchema, id) |> Repo.preload(:source)
  end

  @doc """
  Creates a new image record.
  """
  @spec create_image(map()) :: {:ok, ImageSchema.t()} | {:error, Ecto.Changeset.t()}
  def create_image(attrs) do
    %ImageSchema{}
    |> image_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an image record.

  If the image is being set as default, clears the default flag
  from all other images for the same species.
  """
  @spec update_image(ImageSchema.t(), map()) ::
          {:ok, ImageSchema.t()} | {:error, Ecto.Changeset.t()}
  def update_image(%ImageSchema{} = image, attrs) do
    changeset = image_changeset(image, attrs)

    if Ecto.Changeset.get_change(changeset, :default) == true do
      update_image_with_default(image, changeset)
    else
      Repo.update(changeset)
    end
  end

  defp update_image_with_default(image, changeset) do
    Repo.transaction(fn ->
      clear_other_defaults(image)
      do_update_in_transaction(changeset)
    end)
  end

  defp clear_other_defaults(image) do
    from(i in ImageSchema,
      where: i.species_id == ^image.species_id and i.id != ^image.id
    )
    |> Repo.update_all(set: [default: false])
  end

  defp do_update_in_transaction(changeset) do
    case Repo.update(changeset) do
      {:ok, updated} -> updated
      {:error, cs} -> Repo.rollback(cs)
    end
  end

  @doc """
  Deletes an image from the database and S3.

  Deletes all size variants (original, small, medium, large, xlarge) from S3.
  """
  @spec delete_image(ImageSchema.t()) :: {:ok, ImageSchema.t()} | {:error, term()}
  def delete_image(%ImageSchema{} = image) do
    # Delete from S3 first
    case delete_image_from_s3(image.path) do
      :ok ->
        Repo.delete(image)

      {:error, reason} ->
        {:error, {:s3_error, reason}}
    end
  end

  @doc """
  Deletes multiple images by IDs for a species.
  """
  @spec delete_images(integer(), [integer()]) :: {:ok, integer()} | {:error, term()}
  def delete_images(species_id, image_ids) when is_list(image_ids) do
    images =
      from(i in ImageSchema,
        where: i.species_id == ^species_id and i.id in ^image_ids
      )
      |> Repo.all()

    # Delete from S3 first
    s3_results =
      images
      |> Enum.map(fn image -> delete_image_from_s3(image.path) end)
      |> Enum.filter(fn result -> result != :ok end)

    if s3_results == [] do
      {count, _} =
        from(i in ImageSchema,
          where: i.species_id == ^species_id and i.id in ^image_ids
        )
        |> Repo.delete_all()

      {:ok, count}
    else
      {:error, {:s3_errors, s3_results}}
    end
  end

  @doc """
  Sets an image as the default for its species.

  Clears the default flag from all other images for the same species.
  """
  @spec set_default(ImageSchema.t()) :: {:ok, ImageSchema.t()} | {:error, Ecto.Changeset.t()}
  def set_default(%ImageSchema{} = image) do
    update_image(image, %{default: true})
  end

  @doc """
  Reorders images for a species.

  Takes a list of image IDs in the desired order. The first image
  in the list becomes the default.
  """
  @spec reorder_images(integer(), [integer()]) :: :ok | {:error, term()}
  def reorder_images(species_id, ordered_ids) when is_list(ordered_ids) do
    Repo.transaction(fn ->
      # Clear all defaults first
      from(i in ImageSchema, where: i.species_id == ^species_id)
      |> Repo.update_all(set: [default: false])

      # Set the first image as default
      case List.first(ordered_ids) do
        nil ->
          :ok

        first_id ->
          from(i in ImageSchema, where: i.id == ^first_id)
          |> Repo.update_all(set: [default: true])
      end
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates image size variants and uploads them to S3.

  This is called after the original image has been uploaded.
  The function downloads the original, resizes it, and uploads
  the variants asynchronously.
  """
  @spec generate_size_variants(String.t()) :: :ok | {:error, term()}
  def generate_size_variants(original_path) do
    original_url = cdn_url() <> "/" <> original_path

    case fetch_original_image(original_url) do
      {:ok, body} ->
        spawn_resize_tasks(body, original_path)
        :ok

      {:error, reason} ->
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

  defp spawn_resize_tasks(body, original_path) do
    Enum.each(@sizes, fn {size_name, width} ->
      Task.start(fn -> resize_and_upload(body, original_path, size_name, width) end)
    end)
  end

  # Private functions

  defp image_changeset(image, attrs) do
    import Ecto.Changeset

    image
    |> cast(attrs, [
      :species_id,
      :source_id,
      :path,
      :default,
      :creator,
      :attribution,
      :license,
      :licenselink,
      :sourcelink,
      :uploader,
      :lastchangedby,
      :caption
    ])
    |> validate_required([:species_id, :path])
  end

  defp delete_image_from_s3(path) when is_binary(path) do
    # Generate all size variant keys
    keys =
      [:original, :small, :medium, :large, :xlarge]
      |> Enum.map(fn size ->
        size_str = Atom.to_string(size)
        String.replace(path, "original", size_str)
      end)

    # Delete all variants
    objects = Enum.map(keys, fn key -> %{key: key} end)

    case ExAws.S3.delete_multiple_objects(bucket(), objects) |> ExAws.request() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp delete_image_from_s3(_), do: :ok

  defp resize_and_upload(image_data, original_path, size_name, target_width) do
    size_str = Atom.to_string(size_name)
    new_path = String.replace(original_path, "original", size_str)
    format = get_image_format(original_path)
    content_type = format_to_content_type(format)

    with {:ok, img} <- ImageLib.open(image_data),
         {:ok, resized} <- ImageLib.thumbnail(img, target_width),
         {:ok, output_data} <- ImageLib.write(resized, :memory, suffix: ".#{format}") do
      upload_to_s3(new_path, output_data, content_type)
    else
      {:error, reason} -> {:error, {:resize_failed, reason}}
    end
  end

  defp get_image_format(path) do
    if String.ends_with?(path, ".png"), do: :png, else: :jpeg
  end

  defp format_to_content_type(:png), do: "image/png"
  defp format_to_content_type(:jpeg), do: "image/jpeg"

  defp upload_to_s3(path, data, content_type) do
    ExAws.S3.put_object(bucket(), path, data,
      content_type: content_type,
      acl: :public_read
    )
    |> ExAws.request()
  end

  @doc """
  Gets all images for a source, ordered by species name.
  """
  @spec list_images_for_source(integer()) :: [ImageSchema.t()]
  def list_images_for_source(source_id) do
    from(i in ImageSchema,
      join: src in assoc(i, :source),
      left_join: sp in Species,
      on: i.species_id == sp.id,
      where: i.source_id == ^source_id,
      order_by: [asc: sp.name, asc: i.id],
      preload: [source: src]
    )
    |> Repo.all()
  end

  @doc """
  Returns the total count of images in the database.
  """
  @spec count_images() :: integer()
  def count_images do
    from(i in ImageSchema, select: count(i.id))
    |> Repo.one()
  end

  @doc """
  Lists all species that have images, with their image counts.
  """
  @spec list_species_with_images() :: [map()]
  def list_species_with_images do
    from(i in ImageSchema,
      join: s in Species,
      on: i.species_id == s.id,
      group_by: [s.id, s.name],
      select: %{
        species_id: s.id,
        species_name: s.name,
        image_count: count(i.id)
      },
      order_by: s.name
    )
    |> Repo.all()
  end

  @doc """
  Searches for species by name for image management.
  """
  @spec search_species(String.t()) :: [map()]
  def search_species(query) when is_binary(query) do
    search_term = "%#{String.downcase(query)}%"

    from(s in Species,
      left_join: i in ImageSchema,
      on: i.species_id == s.id,
      where: fragment("lower(?) LIKE ?", s.name, ^search_term),
      group_by: [s.id, s.name],
      select: %{
        id: s.id,
        name: s.name,
        image_count: count(i.id)
      },
      order_by: s.name,
      limit: 20
    )
    |> Repo.all()
  end

  # Article Image Functions

  @doc """
  Generates the S3 path for an article image.

  Format: articles/{article_id}/{timestamp}.{ext}

  Uses article ID instead of slug since slugs can change but IDs are stable.
  """
  @spec generate_article_path(integer(), String.t()) :: String.t()
  def generate_article_path(article_id, extension) when is_integer(article_id) do
    timestamp = System.system_time(:millisecond)
    ext = String.trim_leading(extension, ".")
    "articles/#{article_id}/#{timestamp}.#{ext}"
  end

  @doc """
  Returns the full CDN URL for an article image path.
  """
  @spec article_image_url(String.t()) :: String.t()
  def article_image_url(path) do
    "#{cdn_url()}/#{path}"
  end

  @doc """
  Lists all images in the articles folder on S3.

  Returns a list of maps with :path, :url, :name, :folder, and :article_id keys.
  """
  @spec list_article_images() :: [map()]
  def list_article_images do
    list_article_images_with_prefix("articles/")
  end

  @doc """
  Lists images for a specific article by ID.
  """
  @spec list_article_images_for_article(integer()) :: [map()]
  def list_article_images_for_article(article_id) do
    list_article_images_with_prefix("articles/#{article_id}/")
  end

  # Lists images in a specific articles subfolder on S3.
  @spec list_article_images_with_prefix(String.t()) :: [map()]
  defp list_article_images_with_prefix(prefix) do
    case ExAws.S3.list_objects(bucket(), prefix: prefix) |> ExAws.request() do
      {:ok, %{body: body}} ->
        # contents may be missing, nil, or a list depending on S3 response
        contents = Map.get(body, :contents) || []
        contents = if is_list(contents), do: contents, else: []

        contents
        |> Enum.filter(&image_file?/1)
        |> Enum.map(&transform_s3_object/1)
        |> Enum.sort_by(& &1.last_modified, :desc)

      {:error, reason} ->
        Logger.warning("Failed to list article images: #{inspect(reason)}")
        []
    end
  end

  defp image_file?(obj) do
    String.ends_with?(obj.key, [".jpg", ".jpeg", ".png", ".gif", ".webp"])
  end

  defp transform_s3_object(obj) do
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
  Deletes an article image from S3.

  Takes the full S3 path (e.g., "articles/123/1234567890.jpg").
  Returns :ok on success or {:error, reason} on failure.
  """
  @spec delete_article_image(String.t()) :: :ok | {:error, term()}
  def delete_article_image(path) when is_binary(path) do
    Logger.info("Attempting to delete article image: #{path} from bucket: #{bucket()}")

    case ExAws.S3.delete_object(bucket(), path) |> ExAws.request() do
      {:ok, _} ->
        Logger.info("Successfully deleted article image: #{path}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete article image: #{path}, reason: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
