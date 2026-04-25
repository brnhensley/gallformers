defmodule Gallformers.IngestionPipeline.SchemaTest do
  use ExUnit.Case, async: true

  alias Gallformers.IngestionPipeline.Schema

  describe "load/0" do
    test "loads the gall_record schema from disk" do
      schema = Schema.load()

      assert is_map(schema)
      assert schema["$schema"] == "http://json-schema.org/draft-07/schema#"
      assert schema["title"] == "Gall Record"
      assert schema["type"] == "object"

      assert schema["required"] == [
               "gall_species",
               "host_species",
               "traits",
               "description",
               "confidence"
             ]
    end
  end

  describe "prompt_text/0" do
    test "renders schema as human-readable text" do
      prompt = Schema.prompt_text()

      assert String.contains?(prompt, "Data Schema") == true
      assert String.contains?(prompt, "gall_species") == true
      assert String.contains?(prompt, "host_species") == true
      assert String.contains?(prompt, "traits") == true
      assert String.contains?(prompt, "description") == true
      assert String.contains?(prompt, "confidence") == true

      # Trait vocabularies should be included
      assert String.contains?(prompt, ~s("shape":)) == true
      assert String.contains?(prompt, ~s("color":)) == true
      assert String.contains?(prompt, ~s("detachable":)) == true
    end

    test "includes all shape values" do
      prompt = Schema.prompt_text()
      assert String.contains?(prompt, "cluster") == true
      assert String.contains?(prompt, "conical") == true
      assert String.contains?(prompt, "cylindrical") == true
    end

    test "detachable values are listed" do
      prompt = Schema.prompt_text()
      assert String.contains?(prompt, "unknown") == true
      assert String.contains?(prompt, "integral") == true
    end

    test "multi-word vocab values render correctly" do
      prompt = Schema.prompt_text()
      assert String.contains?(prompt, "resinous dots") == true
      assert String.contains?(prompt, "underground (roots+)") == true
      assert String.contains?(prompt, "false chamber") == true
    end
  end

  describe "validate/1" do
    test "validates a minimal valid record" do
      record = [
        %{
          "gall_species" => %{"name" => "Andricus", "family" => "Cynipidae"},
          "host_species" => %{"name" => "Quercus"},
          "traits" => %{},
          "description" => "A gall",
          "confidence" => 0.85
        }
      ]

      assert {:ok, _} = Schema.validate(record)
    end

    test "validates a complete trait record" do
      record = [
        %{
          "gall_species" => %{
            "name" => "Andricus quercuscalifornicus",
            "authority" => "(Cole)",
            "family" => "Cynipidae",
            "order" => "Hymenoptera"
          },
          "host_species" => %{
            "name" => "Quercus lobata",
            "authority" => "Nee",
            "family" => "Fagaceae"
          },
          "traits" => %{
            "shape" => %{"original" => "globular", "suggested" => ["globular"]},
            "color" => %{"original" => "tan", "suggested" => ["tan"]},
            "texture" => %{"original" => nil, "suggested" => []},
            "detachable" => "unknown"
          },
          "description" => "Gall description",
          "location" => "California",
          "confidence" => 0.85
        }
      ]

      assert {:ok, validated} = Schema.validate(record)
      assert length(validated) == 1
    end

    test "returns error for missing required fields" do
      record = [%{"gall_species" => %{"name" => "Andricus"}}]

      assert {:error, :invalid_contract, errors} = Schema.validate(record)
      assert is_list(errors)
      assert Enum.any?(errors, &String.contains?(&1, "Required properties")) == true
    end

    test "returns error for invalid type" do
      record = [
        %{
          "gall_species" => %{"name" => "Andricus", "family" => "Cynipidae"},
          "host_species" => %{"name" => "Quercus"},
          "traits" => %{},
          "description" => "A gall",
          "confidence" => "not a number"
        }
      ]

      assert {:error, :invalid_contract, errors} = Schema.validate(record)
      assert Enum.any?(errors, &String.contains?(&1, "Type mismatch")) == true
    end

    test "returns error for confidence out of range" do
      record = [
        %{
          "gall_species" => %{"name" => "Andricus", "family" => "Cynipidae"},
          "host_species" => %{"name" => "Quercus"},
          "traits" => %{},
          "description" => "A gall",
          "confidence" => 1.5
        }
      ]

      assert {:error, :invalid_contract, errors} = Schema.validate(record)

      assert Enum.any?(errors, &String.contains?(&1, "Expected the value to be <= 1.0")) ==
               true
    end

    test "returns error for invalid suggested vocabulary value" do
      record = [
        %{
          "gall_species" => %{"name" => "Andricus", "family" => "Cynipidae"},
          "host_species" => %{"name" => "Quercus"},
          "traits" => %{
            "shape" => %{"original" => "banana-like", "suggested" => ["banana"]}
          },
          "description" => "A gall",
          "confidence" => 0.8
        }
      ]

      assert {:error, :invalid_contract, errors} = Schema.validate(record)

      assert Enum.any?(
               errors,
               &String.contains?(&1, ~s(traits.shape.suggested contains invalid value "banana"))
             ) == true
    end

    test "returns error for non-list input" do
      assert {:error, :invalid_contract, ["Expected a list of records"]} =
               Schema.validate("not a list")

      assert {:error, :invalid_contract, ["Expected a list of records"]} = Schema.validate(nil)
    end
  end

  describe "vocabulary accessors" do
    test "shape_vocab returns list of valid shapes" do
      vocab = Schema.shape_vocab()
      assert is_list(vocab)
      assert "cluster" in vocab
      assert "conical" in vocab
      assert "sphere" in vocab
    end

    test "detachable_vocab returns all valid values" do
      vocab = Schema.detachable_vocab()
      assert vocab == ["unknown", "integral", "detachable", "both"]
    end

    test "plant_part_vocab keeps multi-word values intact" do
      vocab = Schema.plant_part_vocab()
      assert "underground (roots+)" in vocab
      assert "at leaf vein angles" in vocab
    end

    test "trait_vocabs returns all vocabularies as map" do
      vocabs = Schema.trait_vocabs()
      assert is_map(vocabs)
      assert vocabs.shape == Schema.shape_vocab()
      assert vocabs.color == Schema.color_vocab()
      assert vocabs.detachable == Schema.detachable_vocab()
    end
  end
end
