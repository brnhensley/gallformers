defmodule GallformersWeb.BrowserSupport do
  @moduledoc """
  Shared browser support policy sourced from Browserslist-generated regex data.
  """

  @regex_path Path.expand("../../priv/browser_support_regex.json", __DIR__)
  @external_resource @regex_path
  @regex_data @regex_path |> File.read!() |> Jason.decode!()
  @regex_source @regex_data["source"]
  @regex_flags @regex_data["flags"] || ""
  @supported_regex Regex.compile!(@regex_source, @regex_flags)

  @banner_message """
  This browser version is not fully supported and some parts of Gallformers may not work correctly. \
  For the best experience, update your browser. If you are using an older iPad/iPhone go yell at Apple \
  for abandoning hardware that is still useful.
  """

  @spec supported_user_agent?(String.t() | nil) :: boolean()
  def supported_user_agent?(nil), do: true
  def supported_user_agent?(user_agent), do: Regex.match?(@supported_regex, user_agent)

  @spec unsupported_user_agent?(String.t() | nil) :: boolean()
  def unsupported_user_agent?(user_agent), do: not supported_user_agent?(user_agent)

  @spec banner_message() :: String.t()
  def banner_message, do: @banner_message
end
