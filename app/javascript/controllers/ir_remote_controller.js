import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { urlTemplate: String }

  press(event) {
    event.preventDefault()
    const button = event.currentTarget
    const command = button.dataset.command
    if (!command) return

    this.send(command)
    button.classList.add("is-down")

    if (button.dataset.hold === "true") {
      this.clearHold()
      this.holdTimer = setInterval(() => this.send(command), 220)
    }
  }

  release(event) {
    event.currentTarget.classList.remove("is-down")
    this.clearHold()
  }

  disconnect() {
    this.clearHold()
  }

  clearHold() {
    if (this.holdTimer) {
      clearInterval(this.holdTimer)
      this.holdTimer = null
    }
  }

  send(command) {
    const url = this.urlTemplateValue.replace("COMMAND", encodeURIComponent(command))
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(url, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": token || "",
        "X-Requested-With": "XMLHttpRequest"
      }
    }).catch(() => {})
  }
}
