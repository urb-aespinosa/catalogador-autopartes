import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Broadcasts sent before the stream subscription is confirmed never reach
// the page. Turbo marks <turbo-cable-stream-source> with the "connected"
// attribute when the subscription is confirmed (also after a reconnect), so
// at that moment the page asks the server for the current progress.
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.observer = new MutationObserver(() => {
      if (this.element.hasAttribute("connected")) this.catchUp()
    })
    this.observer.observe(this.element, { attributes: true, attributeFilter: ["connected"] })
    if (this.element.hasAttribute("connected")) this.catchUp()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  async catchUp() {
    if (this.finished()) return

    const response = await fetch(this.urlValue, { headers: { Accept: "text/vnd.turbo-stream.html" } })
    if (!response.ok) return

    const html = await response.text()
    // The final broadcast may arrive while this request is in flight; never
    // replace that final state with an older one.
    if (!this.finished()) Turbo.renderStreamMessage(html)
  }

  finished() {
    return document.getElementById("progress")?.dataset.status === "done"
  }
}
