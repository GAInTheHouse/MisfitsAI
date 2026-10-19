import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  select(event) {
    const input = event.currentTarget.querySelector("input")
    if (!input) return
    input.checked = true
    input.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
