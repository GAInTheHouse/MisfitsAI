import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { messages: Array, interval: { type: Number, default: 2500 } }

  connect() {
    if (!this.messagesValue.length) return
    this.index = 0
    this.element.textContent = this.messagesValue[0]
    this.timer = setInterval(() => this.rotate(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  rotate() {
    this.index = (this.index + 1) % this.messagesValue.length
    this.element.textContent = this.messagesValue[this.index]
  }
}
