defmodule Gallformers.ChangesetHelpersTest do
  use ExUnit.Case, async: true

  import Gallformers.ChangesetHelpers

  alias Ecto.Changeset

  defmodule TestSchema do
    use Ecto.Schema

    schema "test" do
      field :url, :string
    end
  end

  defp changeset(attrs) do
    Changeset.cast(%TestSchema{}, attrs, [:url])
  end

  describe "validate_url/2" do
    test "accepts valid http URL" do
      cs = changeset(%{url: "http://example.com"}) |> validate_url(:url)
      assert cs.valid?
    end

    test "accepts valid https URL" do
      cs = changeset(%{url: "https://example.com/path?q=1"}) |> validate_url(:url)
      assert cs.valid?
    end

    test "accepts empty string" do
      cs = changeset(%{url: ""}) |> validate_url(:url)
      assert cs.valid?
    end

    test "accepts nil (no change)" do
      cs = changeset(%{}) |> validate_url(:url)
      assert cs.valid?
    end

    test "rejects URL without scheme" do
      cs = changeset(%{url: "doi.org/10.1234"}) |> validate_url(:url)
      refute cs.valid?
      assert {"must be a valid URL starting with http:// or https://", _} = cs.errors[:url]
    end

    test "rejects plain text" do
      cs = changeset(%{url: "some random text"}) |> validate_url(:url)
      refute cs.valid?
    end

    test "rejects literal 'none'" do
      cs = changeset(%{url: "none"}) |> validate_url(:url)
      refute cs.valid?
    end

    test "auto-prepends https:// for www. prefix" do
      cs = changeset(%{url: "www.example.com/page"}) |> validate_url(:url)
      assert cs.valid?
      assert Changeset.get_change(cs, :url) == "https://www.example.com/page"
    end

    test "trims whitespace" do
      cs = changeset(%{url: "  https://example.com  "}) |> validate_url(:url)
      assert cs.valid?
      assert Changeset.get_change(cs, :url) == "https://example.com"
    end

    test "trims whitespace-only to empty string" do
      cs = changeset(%{url: "   "}) |> validate_url(:url)
      assert cs.valid?
      assert Changeset.get_field(cs, :url) in [nil, ""]
    end
  end
end
