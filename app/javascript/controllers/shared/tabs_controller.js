import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "tab"]
  static values = { index: { type: Number, default: 0 } }

  select(event) {
    const index = this.tabTargets.indexOf(event.currentTarget)
    if (index < 0) return
    this.indexValue = index
    this.refresh()
  }

  indexValueChanged() {
    this.refresh()
  }

  refresh() {
    this.tabTargets.forEach((tab, i) => {
      tab.classList.toggle("active", i === this.indexValue)
      tab.setAttribute("aria-selected", i === this.indexValue ? "true" : "false")
    })
    this.panelTargets.forEach((panel, i) => {
      panel.hidden = i !== this.indexValue
    })
  }
}
