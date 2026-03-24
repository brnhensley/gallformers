defmodule Gallformers.INaturalist do
  @moduledoc """
  Context for interacting with the iNaturalist API.

  Handles observation fetching, photo downloading, URL parsing, and
  license mapping between iNat and Gallformers formats.
  """
  use Boundary, deps: [], exports: :all

  require Logger

  alias Gallformers.INaturalist.{Observation, Photo}

  @api_base "https://api.inaturalist.org/v1"
  @user_agent "Gallformers/1.0 (gallformers.org)"

  @license_map %{
    "cc0" => "Public Domain / CC0",
    "cc-by" => "CC-BY",
    "cc-by-sa" => "CC-BY-SA",
    "cc-by-nc" => "CC-BY-NC",
    "cc-by-nc-sa" => "CC-BY-NC-SA",
    "cc-by-nd" => "CC-BY-ND",
    "cc-by-nc-nd" => "CC-BY-NC-ND"
  }

  @observation_url_pattern ~r{https?://(?:www\.)?inaturalist\.org/observations/(\d+)}

  @doc """
  Maps an iNat `license_code` to a Gallformers license string.
  Returns "All Rights Reserved" for nil (no license).
  """
  @spec map_license(String.t() | nil) :: String.t()
  def map_license(nil), do: "All Rights Reserved"
  def map_license(code), do: Map.get(@license_map, code, "All Rights Reserved")

  @doc """
  Parses an iNaturalist observation URL or bare ID into an observation ID.
  """
  @spec parse_observation_id(String.t()) :: {:ok, String.t()} | {:error, :invalid_input}
  def parse_observation_id(input) when is_binary(input) do
    input = String.trim(input)

    cond do
      input == "" ->
        {:error, :invalid_input}

      Regex.match?(~r/^\d+$/, input) ->
        {:ok, input}

      match = Regex.run(@observation_url_pattern, input) ->
        {:ok, Enum.at(match, 1)}

      true ->
        {:error, :invalid_input}
    end
  end

  @doc """
  Fetches an iNaturalist observation by URL or ID.
  Returns `{:ok, Observation.t()}` or `{:error, reason}`.
  """
  @spec fetch_observation(String.t()) :: {:ok, Observation.t()} | {:error, atom()}
  def fetch_observation(input) do
    with {:ok, id} <- parse_observation_id(input),
         {:ok, json} <- do_fetch_observation(id) do
      parse_observation_response(json)
    end
  end

  @doc """
  Downloads a photo from the given URL. Returns `{:ok, binary}` or `{:error, reason}`.
  """
  @spec download_photo(String.t()) :: {:ok, binary()} | {:error, term()}
  def download_photo(url) do
    case Req.get(url, headers: [{"user-agent", @user_agent}]) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Parses a raw iNat API observation response into an Observation struct.
  """
  @spec parse_observation_response(map()) :: {:ok, Observation.t()} | {:error, :not_found}
  def parse_observation_response(%{"results" => [raw | _]}) do
    photos =
      (raw["photos"] || [])
      |> Enum.map(fn p ->
        license_code = p["license_code"]
        mapped = map_license(license_code)

        %Photo{
          id: p["id"],
          thumbnail_url: photo_size_url(p["url"], "medium"),
          original_url: photo_size_url(p["url"], "original"),
          license_code: license_code,
          mapped_license: mapped,
          all_rights_reserved?: license_code == nil
        }
      end)

    obs = %Observation{
      id: raw["id"],
      taxon_name: get_in(raw, ["taxon", "name"]),
      observer_login: get_in(raw, ["user", "login"]),
      observer_name: get_in(raw, ["user", "name"]),
      url: "https://www.inaturalist.org/observations/#{raw["id"]}",
      photos: photos
    }

    {:ok, obs}
  end

  def parse_observation_response(%{"results" => []}), do: {:error, :not_found}
  def parse_observation_response(_), do: {:error, :invalid_response}

  @doc """
  Formats the creator field from iNat user login and display name.
  """
  @spec format_creator(String.t(), String.t() | nil) :: String.t()
  def format_creator(login, nil), do: login
  def format_creator(login, ""), do: login
  def format_creator(login, name), do: "#{login} - #{name}"

  # Replace "square" (or any size) in a photo URL with the requested size.
  defp photo_size_url(url, size) when is_binary(url) do
    String.replace(url, ~r{/square\.(jpe?g|png)}, "/#{size}.\\1")
  end

  defp do_fetch_observation(id) do
    url = "#{@api_base}/observations/#{id}"

    case Req.get(url, headers: [{"user-agent", @user_agent}]) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status}} ->
        Logger.warning("iNat API returned status #{status} for observation #{id}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.error("iNat API request failed for observation #{id}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
