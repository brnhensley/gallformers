defmodule GallformersWeb.API.FilterFieldController do
  @moduledoc """
  API controller for filter fields endpoint.

  Returns all available filter field options for the ID tool.
  """

  use GallformersWeb, :controller

  alias Gallformers.IDTool

  @doc """
  GET /api/v2/filter-fields
  Returns all filter field options.
  """
  def index(conn, _params) do
    options = IDTool.get_filter_options()

    json(conn, %{
      alignments: format_filter_field(options.alignments, :alignment),
      cells: format_filter_field(options.cells, :cells),
      colors: format_filter_field(options.colors, :color),
      forms: format_filter_field(options.forms, :form),
      locations: format_filter_field(options.locations, :location),
      seasons: format_filter_field(options.seasons, :season),
      shapes: format_filter_field(options.shapes, :shape),
      textures: format_filter_field(options.textures, :texture),
      walls: format_filter_field(options.walls, :walls)
    })
  end

  defp format_filter_field(items, field_name) do
    Enum.map(items, fn item ->
      %{
        id: item.id,
        field: Map.get(item, field_name),
        description: Map.get(item, :description)
      }
    end)
  end
end
