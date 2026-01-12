defmodule GallformersWeb.API.HostController do
  @moduledoc """
  API controller for host endpoints.
  """

  use GallformersWeb, :controller

  alias Gallformers.{Hosts, Search}

  @doc """
  GET /api/v2/hosts
  Lists all hosts with optional search and pagination.
  Supports ?simple=true for lightweight response.
  """
  def index(conn, params) do
    limit = parse_int(params["limit"])
    offset = parse_int(params["offset"]) || 0
    query = params["q"]
    simple = params["simple"] == "true"

    {hosts, total} =
      case {query, limit} do
        {nil, nil} ->
          all = Hosts.list_hosts()
          {all, length(all)}

        {nil, limit} ->
          total = Hosts.count_hosts()
          paginated = Hosts.list_hosts_paginated(limit, offset)
          {paginated, total}

        {query, nil} ->
          results = Search.search_hosts(query)
          {results, length(results)}

        {query, limit} ->
          total = Search.count_search_hosts(query)
          results = Search.search_hosts_paginated(query, limit, offset)
          {results, total}
      end

    response =
      if simple do
        Enum.map(hosts, &host_to_simple_response/1)
      else
        Enum.map(hosts, &host_to_response/1)
      end

    json(conn, %{
      data: response,
      total: total,
      limit: limit,
      offset: offset
    })
  end

  @doc """
  GET /api/v2/hosts/:id
  Gets a single host by ID with full details.
  """
  def show(conn, %{"id" => id} = params) do
    simple = params["simple"] == "true"

    with {:ok, id} <- parse_id(id),
         {:ok, host} <- fetch_host(id) do
      response = build_host_response(host, simple)
      json(conn, response)
    else
      {:error, :invalid_id} -> bad_request(conn, "Invalid host ID")
      {:error, :not_found} -> not_found(conn, "Host not found")
    end
  end

  defp parse_id(id) do
    case parse_int(id) do
      nil -> {:error, :invalid_id}
      id -> {:ok, id}
    end
  end

  defp fetch_host(id) do
    case Hosts.get_host(id) do
      nil -> {:error, :not_found}
      host -> {:ok, host}
    end
  end

  defp build_host_response(host, true), do: host_to_simple_response(host)
  defp build_host_response(host, false), do: host_to_full_response(host)

  defp bad_request(conn, message) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: message})
  end

  defp not_found(conn, message) do
    conn
    |> put_status(:not_found)
    |> json(%{error: message})
  end

  # Private functions

  defp host_to_response(host) do
    %{
      id: host.id,
      name: host.name,
      taxoncode: host.taxoncode,
      datacomplete: host.datacomplete
    }
  end

  defp host_to_simple_response(host) do
    places = Hosts.get_places_for_host(host.id)

    %{
      id: host.id,
      name: host.name,
      taxoncode: host.taxoncode,
      datacomplete: host.datacomplete,
      places: places
    }
  end

  defp host_to_full_response(host) do
    places = Hosts.get_places_for_host(host.id)
    galls = Hosts.get_galls_for_host(host.id)

    %{
      id: host.id,
      name: host.name,
      taxoncode: host.taxoncode,
      datacomplete: host.datacomplete,
      places: places,
      galls:
        Enum.map(galls, fn g ->
          %{id: g.id, name: g.name, undescribed: g.undescribed}
        end)
    }
  end

  defp parse_int(nil), do: nil

  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_int(int) when is_integer(int), do: int
end
