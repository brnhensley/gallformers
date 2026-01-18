defmodule Gallformers.Accounts do
  @moduledoc """
  The Accounts context handles user authentication and authorization.

  Authentication is handled by Auth0 via Ueberauth. User profiles are stored in
  the local database for preferences and public display (like the About page),
  but Auth0 remains the source of truth for authentication and authorization.

  Authorization is role-based, with roles provided by Auth0 custom claims:
  - `admin`: Can access admin features and modify data
  - `superadmin`: Full access including dangerous operations
  """

  import Ecto.Query

  alias Gallformers.Accounts.Auth0User
  alias Gallformers.Accounts.User
  alias Gallformers.Repo

  @doc """
  Fetches the current user from the session.

  Returns nil if no user is logged in.
  """
  @spec get_user_from_session(Plug.Conn.t() | map()) :: Auth0User.t() | nil
  def get_user_from_session(%Plug.Conn{} = conn) do
    Plug.Conn.get_session(conn, :current_user)
  end

  def get_user_from_session(%{} = session) do
    Map.get(session, "current_user")
  end

  @doc """
  Stores the user in the session after successful authentication.
  """
  @spec put_user_in_session(Plug.Conn.t(), Auth0User.t()) :: Plug.Conn.t()
  def put_user_in_session(conn, %Auth0User{} = user) do
    conn
    |> Plug.Conn.put_session(:current_user, user)
    |> Plug.Conn.configure_session(renew: true)
  end

  @doc """
  Removes the user from the session (logout).
  """
  @spec clear_session(Plug.Conn.t()) :: Plug.Conn.t()
  def clear_session(conn) do
    Plug.Conn.configure_session(conn, drop: true)
  end

  @doc """
  Creates a User struct from an Ueberauth authentication response.
  """
  @spec user_from_auth(Ueberauth.Auth.t()) :: Auth0User.t()
  def user_from_auth(%Ueberauth.Auth{} = auth) do
    Auth0User.from_auth(auth)
  end

  @doc """
  Returns true if the user is an admin (or superadmin).
  """
  @spec admin?(Auth0User.t() | nil) :: boolean()
  def admin?(nil), do: false
  def admin?(%Auth0User{} = user), do: Auth0User.admin?(user)

  @doc """
  Returns true if the user is a superadmin.
  """
  @spec superadmin?(Auth0User.t() | nil) :: boolean()
  def superadmin?(nil), do: false
  def superadmin?(%Auth0User{} = user), do: Auth0User.superadmin?(user)

  @doc """
  Returns the Auth0 logout URL.

  This URL will clear the Auth0 session and redirect back to the specified URL.
  """
  @spec logout_url(String.t()) :: String.t()
  def logout_url(return_to) do
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth, [])
    domain = Keyword.get(config, :domain, "")
    client_id = Keyword.get(config, :client_id, "")

    "https://#{domain}/v2/logout?" <>
      URI.encode_query(%{
        "client_id" => client_id,
        "returnTo" => return_to
      })
  end

  # ============================================================================
  # User Profile Functions (Database-backed)
  # ============================================================================

  @doc """
  Gets a user profile by ID.

  Returns `nil` if the user does not exist.

  ## Examples

      iex> get_user(123)
      %User{}

      iex> get_user(999)
      nil
  """
  @spec get_user(integer()) :: User.t() | nil
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a user profile by Auth0 ID.

  Returns `nil` if no user with that Auth0 ID exists.

  ## Examples

      iex> get_user_by_auth0_id("auth0|123")
      %User{}

      iex> get_user_by_auth0_id("auth0|unknown")
      nil
  """
  @spec get_user_by_auth0_id(String.t()) :: User.t() | nil
  def get_user_by_auth0_id(auth0_id) do
    Repo.get_by(User, auth0_id: auth0_id)
  end

  @doc """
  Creates a new user profile.

  ## Examples

      iex> create_user(%{auth0_id: "auth0|123", display_name: "Alice"})
      {:ok, %User{}}

      iex> create_user(%{})
      {:error, %Ecto.Changeset{}}
  """
  @spec create_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(attrs) do
    %User{}
    |> User.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing user profile.

  ## Examples

      iex> update_user(user, %{display_name: "New Name"})
      {:ok, %User{}}

      iex> update_user(user, %{inaturalist_url: "not-a-url"})
      {:error, %Ecto.Changeset{}}
  """
  @spec update_user(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(%User{} = user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists users who have opted in to appear on the About page.

  Returns users ordered by display name (nulls last).

  ## Examples

      iex> list_users_for_about_page()
      [%User{show_on_about: true}, ...]
  """
  @spec list_users_for_about_page() :: [User.t()]
  def list_users_for_about_page do
    User
    |> where([u], u.show_on_about == true)
    |> order_by([u], fragment("COALESCE(?, ?) COLLATE NOCASE", u.display_name, u.nickname))
    |> Repo.all()
  end
end
