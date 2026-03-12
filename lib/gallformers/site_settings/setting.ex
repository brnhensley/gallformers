defmodule Gallformers.SiteSettings.Setting do
  @moduledoc """
  Ecto schema for the site_settings table.

  Stores key-value pairs with JSON-encoded values as text.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "site_settings" do
    field :key, :string
    field :value, :string

    timestamps()
  end

  @doc """
  Creates a changeset for a site setting.
  """
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value])
    |> validate_required([:key])
    |> unique_constraint(:key)
  end
end
