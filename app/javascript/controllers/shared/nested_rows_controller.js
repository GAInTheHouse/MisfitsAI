import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  add() {
    const idx = this.containerTarget.children.length
    const fragment = this.templateTarget.content.cloneNode(true)
    fragment.querySelectorAll("[name]").forEach(el => {
      el.name = el.name.replace(/__IDX__/g, idx)
    })
    this.containerTarget.appendChild(fragment)
  }

  remove(event) {
    event.preventDefault()
    event.target.closest("[data-shared--nested-rows-target='row']")?.remove()
  }
}
