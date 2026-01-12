defmodule GallformersWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use GallformersWeb, :html

  # Custom error pages matching the Gallformers design
  embed_templates "error_html/*"

  # Fallback for other error codes - render a plain text page
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
