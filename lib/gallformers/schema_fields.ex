defmodule Gallformers.SchemaFields do
  @moduledoc """
  Behavior for schemas to expose field metadata for UI synchronization.

  Implementing this behavior allows schemas to declare which fields are required,
  enabling forms to automatically display required indicators and validation
  without duplicating this information in both the schema and the form.

  ## Example

      defmodule MyApp.Accounts.User do
        use Ecto.Schema
        @behaviour Gallformers.SchemaFields

        @required_fields [:email, :name]
        @required_associations [:profile]  # Optional

        @impl Gallformers.SchemaFields
        def required_fields, do: @required_fields

        @impl Gallformers.SchemaFields
        def required_associations, do: @required_associations  # Optional

        def changeset(user, attrs) do
          user
          |> cast(attrs, [:email, :name, :bio])
          |> validate_required(@required_fields)
        end
      end

  Then in the form:

      <.input field={@form[:email]} schema={User} />

  The input component will automatically add the required indicator.
  """

  @doc """
  Returns the list of fields that are always required for this schema.

  This should match the fields passed to `Ecto.Changeset.validate_required/2`
  in the schema's changeset function.
  """
  @callback required_fields() :: [atom()]

  @doc """
  Returns the list of associations that are required for this schema.

  This is optional - implement it for schemas that have required relationships
  (e.g., a Gall must have at least one host).
  """
  @callback required_associations() :: [atom()]

  @optional_callbacks [required_associations: 0]

  @doc """
  Checks if a field is required for the given schema.

  Returns `true` if the schema implements SchemaFields and the field
  is in the required fields list.

  ## Examples

      iex> Gallformers.SchemaFields.required?(Gallformers.Sources.Source, :title)
      true

      iex> Gallformers.SchemaFields.required?(Gallformers.Sources.Source, :datacomplete)
      false

      iex> Gallformers.SchemaFields.required?(SomeNonImplementingModule, :any_field)
      false
  """
  @spec required?(module(), atom()) :: boolean()
  def required?(schema, field) when is_atom(schema) and is_atom(field) do
    implements_behaviour?(schema) && field in schema.required_fields()
  end

  @doc """
  Returns the required fields for a schema, or an empty list if the schema
  doesn't implement SchemaFields.

  ## Examples

      iex> Gallformers.SchemaFields.get_required_fields(Gallformers.Sources.Source)
      [:title, :author, :pubyear, :link, :citation, :license]

      iex> Gallformers.SchemaFields.get_required_fields(SomeNonImplementingModule)
      []
  """
  @spec get_required_fields(module()) :: [atom()]
  def get_required_fields(schema) when is_atom(schema) do
    if implements_behaviour?(schema) do
      schema.required_fields()
    else
      []
    end
  end

  @doc """
  Checks if an association is required for the given schema.

  Returns `true` if the schema implements the optional `required_associations/0`
  callback and the association is in the list.

  ## Examples

      iex> Gallformers.SchemaFields.required_association?(Gallformers.Species.Gall, :hosts)
      true

      iex> Gallformers.SchemaFields.required_association?(Gallformers.Sources.Source, :images)
      false
  """
  @spec required_association?(module(), atom()) :: boolean()
  def required_association?(schema, assoc) when is_atom(schema) and is_atom(assoc) do
    implements_associations?(schema) && assoc in schema.required_associations()
  end

  @doc """
  Returns the required associations for a schema, or an empty list if the schema
  doesn't implement the optional `required_associations/0` callback.
  """
  @spec get_required_associations(module()) :: [atom()]
  def get_required_associations(schema) when is_atom(schema) do
    if implements_associations?(schema) do
      schema.required_associations()
    else
      []
    end
  end

  # Check if a module implements required_fields callback
  defp implements_behaviour?(module) do
    Code.ensure_loaded?(module) &&
      function_exported?(module, :required_fields, 0)
  end

  # Check if a module implements optional required_associations callback
  defp implements_associations?(module) do
    Code.ensure_loaded?(module) &&
      function_exported?(module, :required_associations, 0)
  end
end
