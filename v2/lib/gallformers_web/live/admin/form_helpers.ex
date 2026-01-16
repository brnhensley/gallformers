defmodule GallformersWeb.Admin.FormHelpers do
  @moduledoc """
  Reusable helpers for admin form dirty state tracking and discard confirmation.

  ## Usage

  In your LiveView:

      use GallformersWeb.Admin.FormHelpers

  This injects:
  - `init_form_state/1` - Call in mount to initialize assigns
  - `mark_dirty/1` - Call in validate handler to mark form as dirty
  - `handle_form_event/3` - Delegate form events to this handler
  - `close_form/1` - Override to define what happens when form is closed

  ## Example

      def mount(_params, session, socket) do
        socket =
          socket
          |> assign(:current_user, session["current_user"])
          |> init_form_state()

        {:ok, socket}
      end

      def handle_event("validate", params, socket) do
        # ... validation logic ...
        {:noreply, mark_dirty(socket)}
      end

      def handle_event(event, params, socket) when event in ~w(request_cancel cancel_discard confirm_discard) do
        handle_form_event(event, params, socket)
      end

      # Override to define navigation on close
      def close_form(socket) do
        push_navigate(socket, to: ~p"/admin/mylist")
      end
  """

  defmacro __using__(_opts) do
    quote do
      import GallformersWeb.Admin.FormHelpers, only: [discard_confirm_modal: 1]

      @doc """
      Initialize form state assigns. Call in mount/3.
      """
      def init_form_state(socket) do
        socket
        |> Phoenix.Component.assign(:form_dirty, false)
        |> Phoenix.Component.assign(:show_discard_confirm, false)
      end

      @doc """
      Mark the form as dirty. Call in validate handler.
      """
      def mark_dirty(socket) do
        Phoenix.Component.assign(socket, :form_dirty, true)
      end

      @doc """
      Reset the form dirty state. Call when opening a new/edit form.
      """
      def reset_dirty(socket) do
        socket
        |> Phoenix.Component.assign(:form_dirty, false)
        |> Phoenix.Component.assign(:show_discard_confirm, false)
      end

      @doc """
      Handle form-related events. Delegate from handle_event/3.
      """
      def handle_form_event("request_cancel", _params, socket) do
        if socket.assigns.form_dirty do
          {:noreply, Phoenix.Component.assign(socket, :show_discard_confirm, true)}
        else
          {:noreply, close_form(socket)}
        end
      end

      def handle_form_event("cancel_discard", _params, socket) do
        {:noreply, Phoenix.Component.assign(socket, :show_discard_confirm, false)}
      end

      def handle_form_event("confirm_discard", _params, socket) do
        socket =
          socket
          |> Phoenix.Component.assign(:form_dirty, false)
          |> Phoenix.Component.assign(:show_discard_confirm, false)
          |> close_form()

        {:noreply, socket}
      end

      @doc """
      Define what happens when the form is closed/cancelled.
      Override this in your LiveView to customize behavior.
      """
      def close_form(socket) do
        # Default implementation - override in your LiveView
        socket
      end

      defoverridable close_form: 1
    end
  end

  use Phoenix.Component
  import GallformersWeb.UIComponents, only: [modal: 1]

  @doc """
  Renders the discard confirmation modal.

  ## Example

      <.discard_confirm_modal show={@show_discard_confirm} />

  """
  attr :show, :boolean, required: true, doc: "whether to show the modal"

  def discard_confirm_modal(assigns) do
    ~H"""
    <.modal
      :if={@show}
      id="discard-confirm-modal"
      show
      on_cancel={Phoenix.LiveView.JS.push("cancel_discard")}
    >
      <:title>Discard Changes?</:title>
      <p class="text-gray-600 mb-4">
        You have unsaved changes. Are you sure you want to discard them?
      </p>
      <:actions>
        <button
          type="button"
          phx-click="cancel_discard"
          class="px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
        >
          Keep Editing
        </button>
        <button
          type="button"
          phx-click="confirm_discard"
          class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700"
        >
          Discard Changes
        </button>
      </:actions>
    </.modal>
    """
  end
end
