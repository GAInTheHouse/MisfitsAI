import { Controller } from "@hotwired/stimulus"

// Select all / Select none for the photo intake review (design doc 6.6). The buttons stay hidden
// without JavaScript; each checkbox still works on its own.
export default class extends Controller {
  static targets = ["checkbox", "toolbar"]

  connect() {
    this.toolbarTargets.forEach((toolbar) => { toolbar.hidden = false })
  }

  selectAll() {
    this.checkboxTargets.forEach((box) => { box.checked = true })
  }

  selectNone() {
    this.checkboxTargets.forEach((box) => { box.checked = false })
  }
}
