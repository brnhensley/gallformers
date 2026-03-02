defmodule Gallformers.ContentImages do
  @moduledoc """
  Context for managing content images — images owned by articles or keys.

  Provides CRUD operations, attribution checking, and S3 lifecycle management.
  Uses shared attribution logic from `Images.Attribution` and storage operations
  from `Storage`.
  """

  require Logger

  import Ecto.Query
  alias Gallformers.ContentImages.ContentImage
  alias Gallformers.Images.Attribution
  alias Gallformers.Repo
  alias Gallformers.Storage

  # Size variant configs per owner type
  @key_sizes [medium: 800, large: 1200]

  # =============================================================================
  # Listing
  # =============================================================================

  @doc """
  Lists all content images for an article, ordered by sort_order.
  """
  @spec list_images_for_article(integer()) :: [ContentImage.t()]
  def list_images_for_article(article_id) do
    from(i in ContentImage,
      where: i.article_id == ^article_id,
      order_by: [asc: i.sort_order, asc: i.id],
      preload: [:source]
    )
    |> Repo.all()
  end

  @doc """
  Lists all content images for a key, ordered by sort_order.
  """
  @spec list_images_for_key(integer()) :: [ContentImage.t()]
  def list_images_for_key(key_id) do
    from(i in ContentImage,
      where: i.key_id == ^key_id,
      order_by: [asc: i.sort_order, asc: i.id],
      preload: [:source]
    )
    |> Repo.all()
  end

  # =============================================================================
  # Get
  # =============================================================================

  @doc """
  Gets a single content image by ID.
  """
  @spec get_image(integer()) :: ContentImage.t() | nil
  def get_image(id) do
    Repo.get(ContentImage, id) |> Repo.preload(:source)
  end

  @doc """
  Gets a single content image by ID, raising if not found.
  """
  @spec get_image!(integer()) :: ContentImage.t()
  def get_image!(id) do
    Repo.get!(ContentImage, id) |> Repo.preload(:source)
  end

  @doc """
  Builds a map of content_image_id => CDN URL for the given image IDs.

  Used by key rendering to resolve content_image references in couplet JSON.
  Returns a map like `%{42 => "https://cdn.example.com/keys/1/img_medium.jpg"}`.
  Missing IDs are silently omitted.
  """
  @spec build_image_url_map([integer()]) :: %{integer() => String.t()}
  def build_image_url_map([]), do: %{}

  def build_image_url_map(ids) do
    from(i in ContentImage, where: i.id in ^ids, select: {i.id, i.path})
    |> Repo.all()
    |> Map.new(fn {id, path} ->
      # For key images, prefer medium variant if available
      url =
        if String.contains?(path, "original") do
          Storage.cdn_url() <> "/" <> String.replace(path, "original", "medium")
        else
          Storage.cdn_url() <> "/" <> path
        end

      {id, url}
    end)
  end

  # =============================================================================
  # Create
  # =============================================================================

  @doc """
  Creates a content image record and schedules size variant generation.

  `owner_type` is `:article` or `:key`. Articles get no variants,
  keys get medium + large.
  """
  @spec finalize_upload(String.t(), :article | :key, integer(), String.t(), map()) ::
          {:ok, ContentImage.t()} | {:error, Ecto.Changeset.t()}
  def finalize_upload(path, owner_type, owner_id, uploader, extra_attrs \\ %{}) do
    owner_attrs = owner_attrs(owner_type, owner_id)

    attrs =
      Map.merge(
        extra_attrs,
        Map.merge(owner_attrs, %{
          path: path,
          uploader: uploader,
          lastchangedby: uploader
        })
      )

    case create_image(attrs, owner_type, owner_id) do
      {:ok, image} ->
        schedule_size_variants(path, owner_type)
        {:ok, image}

      error ->
        error
    end
  end

  defp owner_attrs(:article, id), do: %{article_id: id}
  defp owner_attrs(:key, id), do: %{key_id: id}

  defp create_image(attrs, owner_type, owner_id) do
    attrs = assign_next_sort_order(attrs, owner_type, owner_id)

    %ContentImage{}
    |> ContentImage.changeset(attrs)
    |> Repo.insert()
  end

  defp assign_next_sort_order(attrs, owner_type, owner_id) do
    {field, value} = owner_field(owner_type, owner_id)

    max_order =
      from(i in ContentImage,
        where: field(i, ^field) == ^value,
        select: max(i.sort_order)
      )
      |> Repo.one() || -1

    Map.put(attrs, :sort_order, max_order + 1)
  end

  defp owner_field(:article, id), do: {:article_id, id}
  defp owner_field(:key, id), do: {:key_id, id}

  defp schedule_size_variants(_path, :article), do: :ok

  defp schedule_size_variants(path, :key) do
    if Application.get_env(:gallformers, :s3_enabled, true) do
      Gallformers.Async.run(fn ->
        try do
          Process.sleep(5000)

          case Storage.generate_size_variants(path, @key_sizes) do
            :ok ->
              Logger.info("Generated key image variants for #{path}")

            {:error, reason} ->
              Logger.error(
                "Failed to generate key image variants for #{path}: #{inspect(reason)}"
              )
          end
        rescue
          e ->
            Logger.error(
              "Exception generating key image variants for #{path}: #{Exception.format(:error, e, __STACKTRACE__)}"
            )
        end
      end)
    end
  end

  # =============================================================================
  # Update
  # =============================================================================

  @doc """
  Updates a content image's metadata.
  """
  @spec update_image(ContentImage.t(), map()) ::
          {:ok, ContentImage.t()} | {:error, Ecto.Changeset.t()}
  def update_image(%ContentImage{} = image, attrs) do
    image
    |> ContentImage.changeset(attrs)
    |> Repo.update()
  end

  # =============================================================================
  # Delete
  # =============================================================================

  @doc """
  Deletes a content image from the database and S3.
  """
  @spec delete_image(ContentImage.t()) :: {:ok, ContentImage.t()} | {:error, term()}
  def delete_image(%ContentImage{} = image) do
    sizes = sizes_for_image(image)

    case Storage.delete_content_image(image.path, sizes) do
      :ok ->
        Repo.delete(image)

      {:error, reason} ->
        {:error, {:s3_error, reason}}
    end
  end

  @doc """
  Batch deletes content images by IDs, scoped to an owner.

  Only deletes images that belong to the specified owner.
  """
  @spec delete_images(:article | :key, integer(), [integer()]) ::
          {:ok, integer()} | {:error, term()}
  def delete_images(owner_type, owner_id, image_ids) when is_list(image_ids) do
    {field, value} = owner_field(owner_type, owner_id)

    images =
      from(i in ContentImage,
        where: field(i, ^field) == ^value and i.id in ^image_ids
      )
      |> Repo.all()

    sizes = sizes_for_owner(owner_type)

    s3_errors =
      images
      |> Enum.map(fn image -> Storage.delete_content_image(image.path, sizes) end)
      |> Enum.reject(&(&1 == :ok))

    if s3_errors == [] do
      {count, _} =
        from(i in ContentImage,
          where: field(i, ^field) == ^value and i.id in ^image_ids
        )
        |> Repo.delete_all()

      {:ok, count}
    else
      {:error, {:s3_errors, s3_errors}}
    end
  end

  @doc """
  Deletes all S3 objects for an article's content images.

  Called before article deletion so CASCADE can clean up DB rows.
  """
  @spec delete_images_from_s3_for_article(integer()) :: :ok
  def delete_images_from_s3_for_article(article_id) do
    delete_images_from_s3(:article_id, article_id, [])
  end

  @doc """
  Deletes all S3 objects for a key's content images.

  Called before key deletion so CASCADE can clean up DB rows.
  """
  @spec delete_images_from_s3_for_key(integer()) :: :ok
  def delete_images_from_s3_for_key(key_id) do
    delete_images_from_s3(:key_id, key_id, @key_sizes)
  end

  defp delete_images_from_s3(field, value, sizes) do
    paths =
      from(i in ContentImage, where: field(i, ^field) == ^value, select: i.path)
      |> Repo.all()

    size_names = Keyword.keys(sizes)

    Enum.each(paths, fn path ->
      case Storage.delete_content_image(path, size_names) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("Failed to delete S3 content image #{path}: #{inspect(reason)}")
      end
    end)

    :ok
  end

  # =============================================================================
  # Reorder
  # =============================================================================

  @doc """
  Reorders content images for an owner.

  Takes a list of image IDs in the desired order.
  """
  @spec reorder_images(:article | :key, integer(), [integer()]) :: :ok | {:error, term()}
  def reorder_images(_owner_type, _owner_id, ordered_ids) when is_list(ordered_ids) do
    Repo.transaction(fn ->
      ordered_ids
      |> Enum.with_index()
      |> Enum.each(fn {image_id, index} ->
        from(i in ContentImage, where: i.id == ^image_id)
        |> Repo.update_all(set: [sort_order: index])
      end)
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # =============================================================================
  # Copy Metadata
  # =============================================================================

  @doc """
  Copies attribution metadata from a source image to target images.
  """
  @spec copy_metadata(integer(), [integer()], String.t()) ::
          {:ok, integer()} | {:error, :source_not_found | term()}
  def copy_metadata(_source_id, [], _updated_by), do: {:ok, 0}

  def copy_metadata(source_id, target_ids, updated_by) when is_list(target_ids) do
    case get_image(source_id) do
      nil ->
        {:error, :source_not_found}

      source ->
        fields = Attribution.attribution_fields()

        metadata =
          fields
          |> Enum.map(fn field -> {field, Map.get(source, field)} end)
          |> Map.new()
          |> Map.put(:source_id, source.source_id)
          |> Map.put(:lastchangedby, updated_by)

        {count, _} =
          from(i in ContentImage, where: i.id in ^target_ids)
          |> Repo.update_all(set: Map.to_list(metadata))

        {:ok, count}
    end
  end

  # =============================================================================
  # Attribution
  # =============================================================================

  defdelegate image_attributed?(image), to: Attribution

  # =============================================================================
  # Helpers
  # =============================================================================

  defp sizes_for_image(%ContentImage{key_id: key_id}) when key_id != nil do
    Keyword.keys(@key_sizes)
  end

  defp sizes_for_image(_), do: []

  defp sizes_for_owner(:key), do: Keyword.keys(@key_sizes)
  defp sizes_for_owner(:article), do: []
end
