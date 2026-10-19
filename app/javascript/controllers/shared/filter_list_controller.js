import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "input"]

  filter() {
    const q = this.inputTarget.value.toLowerCase()
    this.itemTargets.forEach((el) => {
      const text = el.textContent.toLowerCase()
      el.hidden = q.length > 0 && !text.includes(q)
    })
  }
}
