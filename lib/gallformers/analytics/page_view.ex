defmodule Gallformers.Analytics.PageView do
  @moduledoc """
  Schema for page view analytics.

  Stores anonymized page view data for traffic analysis.
  No personally identifiable information is stored.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "page_views" do
    field :path, :string
    field :referrer_host, :string
    field :browser, :string
    field :device_type, :string
    field :visitor_hash, :string

    timestamps(updated_at: false)
  end

  @required_fields [:path, :visitor_hash]
  @optional_fields [:referrer_host, :browser, :device_type]

  @doc false
  def changeset(page_view, attrs) do
    page_view
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
