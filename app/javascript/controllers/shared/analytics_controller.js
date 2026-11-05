import { Controller } from "@hotwired/stimulus"

// Sends GA4 events when GA_MEASUREMENT_ID is configured.
export default class extends Controller {
  static values = { event: String, params: Object }

  connect() {
    if (this.hasEventValue) {
      this.send(this.eventValue, this.hasParamsValue ? this.paramsValue : {})
    }

    document.addEventListener("turbo:load", this.#onPageView)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.#onPageView)
  }

  avatarPreviewOpen(event) {
    const { day, eventType } = event.detail || {}
    this.send("avatar_preview_open", { day, event_type: eventType })
    this.#startOutfitTimer(event.target)
  }

  #startOutfitTimer(el) {
    if (!el) return
    const timer = setTimeout(() => {
      const day = el.dataset.day
      const eventType = el.dataset.eventType
      this.send("outfit_accepted", { label: `${day}:${eventType}` })
    }, 2000)
    el.addEventListener("click", () => clearTimeout(timer), { once: true })
  }

  send(eventName, params = {}) {
    if (typeof gtag !== "undefined") {
      gtag("event", eventName, params)
    }
  }

  #onPageView = () => {
    if (typeof gtag !== "undefined") {
      gtag("config", window.__gaMeasurementId, { send_page_view: true })
    }
  }
}
