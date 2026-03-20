defmodule Gallformers.SiteSettings do
  @moduledoc """
  Site-wide settings with persistent_term caching.

  Settings are key-value pairs stored in the database with JSON-encoded values.
  On startup, all settings are loaded into `:persistent_term` for fast reads.
  Writes go to the database and update the cache synchronously, then broadcast
  via PubSub so other nodes (or the local GenServer) can refresh.

  ## Usage

      SiteSettings.set("banner_enabled", true)
      SiteSettings.get("banner_enabled")        # => true
      SiteSettings.get("missing_key", "default") # => "default"

  ## Convenience functions

      SiteSettings.banner_enabled?()  # => false (default)
      SiteSettings.banner_text()      # => "" (default)
      SiteSettings.read_only?()       # => false (default)
  """
  use GenServer

  require Logger

  alias Gallformers.Repo
  alias Gallformers.SiteSettings.Setting

  @pubsub_topic "site_settings"
  @cache_key {__MODULE__, :cache}

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets a setting value by key. Returns nil if the key doesn't exist.
  """
  @spec get(String.t()) :: term()
  def get(key) do
    get(key, nil)
  end

  @doc """
  Gets a setting value by key, returning `default` if the key doesn't exist.
  """
  @spec get(String.t(), term()) :: term()
  def get(key, default) do
    cache = :persistent_term.get(@cache_key, %{})
    Map.get(cache, key, default)
  end

  @doc """
  Sets a setting value. JSON-encodes the value, upserts to the database,
  updates the persistent_term cache, and broadcasts via PubSub.
  """
  @spec set(String.t(), term()) :: :ok
  def set(key, value) do
    encoded = Jason.encode!(value)

    case Repo.get_by(Setting, key: key) do
      nil ->
        %Setting{}
        |> Setting.changeset(%{key: key, value: encoded})
        |> Repo.insert!()

      existing ->
        existing
        |> Setting.changeset(%{value: encoded})
        |> Repo.update!()
    end

    update_cache(key, value)
    broadcast(key, value)
    :ok
  end

  @doc "Returns whether the site banner is enabled."
  @spec banner_enabled?() :: boolean()
  def banner_enabled?, do: get("banner_enabled", false)

  @doc "Returns the site banner text."
  @spec banner_text() :: String.t()
  def banner_text, do: get("banner_text", "")

  @doc "Returns whether the site is in read-only mode."
  @spec read_only?() :: boolean()
  def read_only?, do: get("read_only", false)

  @doc "Subscribes the calling process to setting change notifications."
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe do
    Phoenix.PubSub.subscribe(Gallformers.PubSub, @pubsub_topic)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    load_all_settings()
    subscribe()
    {:ok, %{}}
  end

  @impl true
  def handle_info({:setting_updated, key, value}, state) do
    update_cache(key, value)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp load_all_settings do
    settings =
      Repo.all(Setting)
      |> Map.new(fn %Setting{key: key, value: value} ->
        {key, decode_value(value)}
      end)

    :persistent_term.put(@cache_key, settings)
  end

  defp update_cache(key, value) do
    cache = :persistent_term.get(@cache_key, %{})
    :persistent_term.put(@cache_key, Map.put(cache, key, value))
  end

  defp decode_value(nil), do: nil

  defp decode_value(encoded) do
    Jason.decode!(encoded)
  end

  defp broadcast(key, value) do
    Phoenix.PubSub.broadcast(
      Gallformers.PubSub,
      @pubsub_topic,
      {:setting_updated, key, value}
    )
  end
end
