import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar", "field"]

  connect() {
    this.initial = this.snapshot()
  }

  changed() {
    const dirty = this.snapshot() !== this.initial
    if (this.hasBarTarget) this.barTarget.hidden = !dirty
  }

  discard() {
    this.element.reset()
    this.changed()
  }

  snapshot() {
    return new FormData(this.element).toString()
  }
}
