import { Controller } from "@hotwired/stimulus"

// Bascule "avant / après" entre un bulletin reçu erroné et sa version vérifiée.
export default class extends Controller {
  static targets = ["before", "after", "tabBefore", "tabAfter"]
  static values = { showing: { type: String, default: "before" } }

  connect() {
    this.userInteracted = false
    this.show("before")

    if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.autoplayId = setInterval(() => {
        if (this.userInteracted) return
        this.show(this.showingValue === "before" ? "after" : "before")
      }, 3200)
    }
  }

  disconnect() {
    clearInterval(this.autoplayId)
  }

  showBefore(event) {
    if (event) this.userInteracted = true
    this.show("before")
  }

  showAfter(event) {
    if (event) this.userInteracted = true
    this.show("after")
  }

  show(which) {
    this.showingValue = which
    const showBefore = which === "before"

    this.beforeTarget.classList.toggle("is-active", showBefore)
    this.afterTarget.classList.toggle("is-active", !showBefore)
    this.beforeTarget.hidden = !showBefore
    this.afterTarget.hidden = showBefore

    this.tabBeforeTarget.classList.toggle("is-active", showBefore)
    this.tabAfterTarget.classList.toggle("is-active", !showBefore)
    this.tabBeforeTarget.setAttribute("aria-selected", String(showBefore))
    this.tabAfterTarget.setAttribute("aria-selected", String(!showBefore))
  }
}
