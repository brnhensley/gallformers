defmodule Gallformers.FilterFields.Form do
  @moduledoc """
  Ecto schema for the form table.

  Describes the overall form of galls (e.g., "leaf fold", "leaf roll").
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          form: String.t() | nil,
          description: String.t() | nil
        }

  schema "form" do
    field :form, :string
    field :description, :string

    many_to_many :galls, Gallformers.Species.Gall,
      join_through: "gallform",
      join_keys: [form_id: :id, gall_id: :id]
  end

  @doc false
  def changeset(form, attrs) do
    form
    |> cast(attrs, [:form, :description])
    |> validate_required([:form])
    |> unique_constraint(:form)
  end
end
