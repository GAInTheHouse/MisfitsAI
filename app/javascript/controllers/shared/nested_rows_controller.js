import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  add() {
    const fragment = this.templateTarget.content.cloneNode(true)
    this.containerTarget.appendChild(fragment)
  }

  remove(event) {
    event.preventDefault()
    event.target.closest("[data-nested-row]")?.remove()
  }
}
