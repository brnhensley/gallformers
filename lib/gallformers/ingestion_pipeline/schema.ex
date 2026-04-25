defmodule Gallformers.IngestionPipeline.Schema do
  @moduledoc """
  Loads and validates gall records against the JSON schema.

  `priv/schemas/gall_record.json` is the canonical definition of the gall
  record contract and controlled vocabularies used for structural validation.
  """

  @schema_path "gall_record.json"

  @trait_vocab_definitions %{
    shape: "shape_vocab",
    color: "color_vocab",
    texture: "texture_vocab",
    walls: "walls_vocab",
    cells: "cells_vocab",
    alignment: "alignment_vocab",
    plant_part: "plant_part_vocab",
    form: "form_vocab",
    season: "season_vocab",
    detachable: "detachable_vocab"
  }

  defp load do
    [:code.priv_dir(:gallformers), "schemas", @schema_path]
    |> Path.join()
    |> File.read!()
    |> Jason.decode!()
  end

  @doc """
  Render a human-readable prompt description of the gall record contract.

  For the canonical machine-readable definition, see
  `priv/schemas/gall_record.json`.
  """
  @spec prompt_text() :: String.t()
  def prompt_text do
    vocabs = trait_vocabs()

    """
    ## Data Schema

    Produce one JSON object per gall-host association with these fields:

    - "gall_species": {"name": "Genus species", "authority": "Author", "family": "Family", "order": "Order"}
    - "host_species": {"name": "Genus species", "authority": "Author", "family": "Family"}
    - "traits": an object with the following keys. Each trait (except detachable) has
      "original" (exact text from source, or null) and "suggested" (list of closest matches
      from the vocabulary below, or empty list):
        - "shape": #{Enum.join(vocabs.shape, ", ")}
        - "color": #{Enum.join(vocabs.color, ", ")}
        - "texture": #{Enum.join(vocabs.texture, ", ")}
        - "walls": #{Enum.join(vocabs.walls, ", ")}
        - "cells": #{Enum.join(vocabs.cells, ", ")}
        - "alignment": #{Enum.join(vocabs.alignment, ", ")}
        - "plant_part": #{Enum.join(vocabs.plant_part, ", ")}
        - "form": #{Enum.join(vocabs.form, ", ")}
        - "season": #{Enum.join(vocabs.season, ", ")}
        - "detachable": one of #{Enum.join(vocabs.detachable, ", ")}
    - "description": full morphological description text from the source
    - "location": collection locality if mentioned, or null
    - "confidence": your confidence in the extraction accuracy, 0.0 to 1.0
    """
  end

  @doc """
  Validate a list of records against the schema.

  Returns `{:ok, records}` on success or `{:error, :invalid_contract, details}` on failure.
  """
  @spec validate([map()]) :: {:ok, [map()]} | {:error, :invalid_contract, [String.t()]}
  def validate(records) when is_list(records) do
    schema = resolved_schema()

    records
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {record, idx}, {:ok, acc} ->
      errors = schema_errors(schema, record, idx) ++ vocabulary_errors(record, idx)

      if errors == [] do
        {:cont, {:ok, [record | acc]}}
      else
        {:halt, {:error, :invalid_contract, errors}}
      end
    end)
    |> case do
      {:ok, validated_records} -> {:ok, Enum.reverse(validated_records)}
      error -> error
    end
  end

  def validate(_), do: {:error, :invalid_contract, ["Expected a list of records"]}

  defp trait_vocabs do
    Enum.into(@trait_vocab_definitions, %{}, fn {trait, definition_name} ->
      {trait, schema_vocab(definition_name)}
    end)
  end

  defp resolved_schema do
    load()
    |> ExJsonSchema.Schema.resolve()
  end

  defp schema_errors(schema, record, idx) do
    case ExJsonSchema.Validator.validate(schema, record) do
      :ok ->
        []

      {:error, errors} when is_list(errors) ->
        Enum.map(errors, &format_schema_error(idx, &1))
    end
  end

  defp vocabulary_errors(record, idx) do
    trait_vocabs()
    |> Map.delete(:detachable)
    |> Enum.flat_map(fn {trait_name, vocab} ->
      record
      |> suggested_values(trait_name)
      |> invalid_suggested_errors(idx, trait_name, vocab)
    end)
  end

  defp schema_vocab("detachable_vocab") do
    load()
    |> get_in(["properties", "traits", "properties", "detachable", "enum"])
    |> Enum.reject(&is_nil/1)
  end

  defp schema_vocab(definition_name) do
    load()
    |> get_in(["definitions", definition_name, "enum"]) || []
  end

  defp format_schema_error(idx, {message, path}) do
    "Record #{idx}: #{format_schema_path(path)} #{message}"
  end

  defp format_schema_path("/"), do: "root"

  defp format_schema_path(path) do
    path
    |> String.replace("/", ".")
    |> String.trim_leading(".")
  end

  defp suggested_values(record, trait_name) do
    case get_in(record, ["traits", Atom.to_string(trait_name), "suggested"]) do
      values when is_list(values) -> values
      _ -> []
    end
  end

  defp invalid_suggested_errors(values, idx, trait_name, vocab) do
    Enum.flat_map(values, fn value ->
      if value in vocab do
        []
      else
        [
          "Record #{idx}: traits.#{trait_name}.suggested contains invalid value #{inspect(value)}"
        ]
      end
    end)
  end
end
