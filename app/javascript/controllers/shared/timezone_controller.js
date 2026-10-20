import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (!this.element.dataset.timezoneSent) {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone
      if (!tz) return

      fetch("/time_zone", {
        method: "PATCH",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: new URLSearchParams({ time_zone: tz })
      }).then(() => {
        this.element.dataset.timezoneSent = "1"
      }).catch(() => {})
    }
  }
}
