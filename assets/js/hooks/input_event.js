// Generic hook that pushes an event on the DOM "input" event (catches paste, autofill, etc.)
// Usage: <input phx-hook="InputEvent" data-event="update_rename_value" />
// Optional: data-target="CID" to push to a specific LiveComponent
// Optional: data-enter-event="add_thing" — pushes that event on Enter keydown
//           (preventing the surrounding form from submitting)
//
// Listens for the server-pushed "clear_input" event:
//   push_event(socket, "clear_input", %{id: "my-input"})
// Resets el.value when payload.id matches. Needed because LiveView won't
// overwrite the value of a focused input on diff.
const InputEvent = {
  mounted() {
    this.el.addEventListener("input", () => {
      const event = this.el.dataset.event
      if (event) {
        this.push(event)
      }
    })

    if (this.el.dataset.enterEvent) {
      this.el.addEventListener("keydown", (e) => {
        if (e.key === "Enter") {
          e.preventDefault()
          e.stopPropagation()
          this.push(this.el.dataset.enterEvent)
        }
      })
    }

    this.handleEvent("clear_input", ({id}) => {
      if (id === this.el.id) {
        this.el.value = ""
      }
    })
  },

  push(event) {
    const target = this.el.dataset.target
    if (target) {
      this.pushEventTo(`[data-phx-component="${target}"]`, event, {value: this.el.value})
    } else {
      this.pushEvent(event, {value: this.el.value})
    }
  }
}

export default InputEvent
