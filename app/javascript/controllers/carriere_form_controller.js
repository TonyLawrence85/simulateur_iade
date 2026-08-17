import { Controller } from "@hotwired/stimulus"

// Contrôleur générique pour les formulaires du simulateur de carrière : affiche/masque
// des blocs de champs en fonction de la valeur sélectionnée sur un radio/select.
// Chaque bloc à révéler porte data-carriere-form-target="revealable" et
// data-show-when="valeur1,valeur2" (les valeurs qui le rendent visible).
export default class extends Controller {
  static targets = ["revealable"]

  connect() {
    this.element.querySelectorAll('[data-action*="carriere-form#toggle"]').forEach(el => {
      if (el.checked || el.tagName === "SELECT") this._apply(el.value)
    })
  }

  toggle(e) {
    this._apply(e.target.value)
  }

  _apply(value) {
    this.revealableTargets.forEach(el => {
      const showValues = (el.dataset.showWhen || "").split(",")
      const show = showValues.includes(value)
      el.classList.toggle("hidden", !show)
    })
  }
}
