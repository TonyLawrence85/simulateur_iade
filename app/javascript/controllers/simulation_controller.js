import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "panel", "stepper",
    "moisPaie", "moisM", "moisM1", "moisM2",
    "imDisplay", "tibDisplay", "tauxHoraireDisplay",
    "sidebarTib", "sidebarBrut", "sidebarNet", "sidebarPrimeIade",
    "progressFill", "confidenceLabel",
    "form", "zoneDisplay", "irDisplay", "sftDisplay", "nbiDisplay"
  ]

  static values = {
    currentStep: { type: Number, default: 0 }
  }

  // Valeur du point FPH (au 01/01/2024 — source officielle)
  VALEUR_POINT = 4.92278
  CTI_POINTS   = 49
  PRIME_VEIL   = 90.00
  PRIME_IADE   = 180.00

  // Grille officielle vérifiée le 18/04/2026
  // Grade 1 : 10 échelons / Grade 2 : 8 échelons
  GRILLE = {
    grade1: { 1:450, 2:478, 3:506, 4:534, 5:563, 6:593, 7:624, 8:656, 9:690, 10:727 },
    grade2: { 1:558, 2:582, 3:615, 4:648, 5:681, 6:714, 7:743, 8:769 }
  }

  MAX_ECHELON = { grade1: 10, grade2: 8 }

  IR_ZONES = { "75":1, "92":1, "93":1, "94":1, "77":2, "78":2, "91":2, "95":2 }
  IR_TAUX  = { 1: 0.03, 2: 0.01, 3: 0.00 }

  connect() {
    this._render(this.currentStepValue)
    this.updateDates()
    this.updateTib()
    this.updateProgress()
  }

  nextStep(e) {
    e.preventDefault()
    if (!this._validateCurrentStep()) return
    if (this.currentStepValue < 5) this._render(this.currentStepValue + 1)
  }

  prevStep(e) {
    e.preventDefault()
    if (this.currentStepValue > 0) this._render(this.currentStepValue - 1)
  }

  goto(e) {
    e.preventDefault()
    const step = parseInt(e.currentTarget.dataset.step)
    this._render(step)
  }

  _render(step) {
    this.currentStepValue = step

    this.panelTargets.forEach(panel => {
      const panelStep = parseInt(panel.dataset.step)
      panel.classList.toggle("hidden", panelStep !== step)
    })

    const stepBtns = this.element.querySelectorAll(".step-item")
    stepBtns.forEach((btn, i) => {
      btn.classList.remove("is-active", "is-done")
      if (i === step) btn.classList.add("is-active")
      else if (i < step) btn.classList.add("is-done")
    })

    // Nettoyer les erreurs de validation de l'étape qu'on quitte
    this.element.querySelectorAll(".step-validation-error").forEach(el => el.remove())
    this.element.querySelectorAll(".field-invalid").forEach(el => el.classList.remove("field-invalid"))

    window.scrollTo({ top: 0, behavior: "smooth" })
    this.updateProgress()
  }

  updateDates() {
    const raw = this.hasMoisPaieTarget ? this.moisPaieTarget.value : null
    if (!raw) return

    const [year, month] = raw.split("-").map(Number)
    const mDate  = new Date(year, month - 1, 1)
    const m1Date = new Date(year, month - 2, 1)
    const m2Date = new Date(year, month - 3, 1)

    const toValue = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`

    if (this.hasMoisMTarget)  this.moisMTarget.value  = toValue(mDate)
    if (this.hasMoisM1Target) this.moisM1Target.value = toValue(m1Date)
    if (this.hasMoisM2Target) this.moisM2Target.value = toValue(m2Date)
  }

  // Changement de grade → mettre à jour la liste des échelons disponibles puis recalculer
  gradeChanged(e) {
    const grade   = e.target.value
    const maxEch  = this.MAX_ECHELON[grade] || 11
    const echelonSelect = this.formTarget.querySelector("[name='simulation_session[echelon]']")
    if (!echelonSelect) return

    const currentVal = parseInt(echelonSelect.value) || 1
    echelonSelect.innerHTML = ""
    for (let i = 1; i <= maxEch; i++) {
      const opt = document.createElement("option")
      opt.value = i
      opt.textContent = i
      if (i === Math.min(currentVal, maxEch)) opt.selected = true
      echelonSelect.appendChild(opt)
    }
    this.updateTib()
  }

  updateIr() {
    const deptCode = this.formTarget.querySelector("[name='simulation_session[departement_code]']")?.value || "75"
    const tib   = this._tib || 0
    const zone  = this.IR_ZONES[deptCode] || 3
    const taux  = this.IR_TAUX[zone] || 0
    const ir    = (tib * taux).toFixed(2)

    if (this.hasZoneDisplayTarget)
      this.zoneDisplayTarget.value = `Zone ${zone} — ${(taux * 100).toFixed(0)}% du TIB`
    if (this.hasIrDisplayTarget)
      this.irDisplayTarget.value = `${this.formatEuros(ir)} €`

    this._ir = parseFloat(ir)
  }

  updateSft() {
    const nb       = parseInt(this.formTarget.querySelector("[name='simulation_session[nb_enfants_sft]']")?.value) || 0
    const tib      = this._tib || 0
    const alternee = this.formTarget.querySelector("[name='simulation_session[garde_alternee]']")?.value === "true"

    let sft = 0
    if (nb === 1)      sft = 2.29
    else if (nb === 2) sft = Math.max(73.04, 10.67 + tib * 0.03)
    else if (nb >= 3)  sft = Math.max(181.56 + (nb - 3) * 129.10, 15.24 + tib * 0.08 + (nb - 3) * (4.57 + tib * 0.06))
    if (alternee && sft > 0) sft /= 2

    if (this.hasSftDisplayTarget)
      this.sftDisplayTarget.value = `${this.formatEuros(sft.toFixed(2))} €`
  }

  updateNbi() {
    const pts = parseInt(this.formTarget.querySelector("[name='simulation_session[nbi_points]']")?.value) || 0
    const nbi = (pts * this.VALEUR_POINT).toFixed(2)

    if (this.hasNbiDisplayTarget)
      this.nbiDisplayTarget.value = `${this.formatEuros(nbi)} €`
  }

  updatePlanning() {
    const tib    = this._tib || 0
    const ir     = this._ir  || 0
    const base   = (tib + ir) * 12 / 1820   // Base horaire FPH

    const hNuit  = parseFloat(this.formTarget.querySelector("[name='simulation_session[heures_nuit]']")?.value) || 0
    const hDim   = parseFloat(this.formTarget.querySelector("[name='simulation_session[heures_dimanche]']")?.value) || 0
    const hFerie = parseFloat(this.formTarget.querySelector("[name='simulation_session[heures_ferie]']")?.value) || 0

    const jma   = base * 0.25 * hNuit          // JMA = 25% × base × heures nuit
    const dimJf = (hDim + hFerie) * 7.50       // IDJF = 7,50 €/h fixe

    const cti   = this.CTI_POINTS * this.VALEUR_POINT * (this._quotite || 1)
    const veil  = this.PRIME_VEIL * (this._quotite || 1)
    const iade  = this.PRIME_IADE * (this._quotite || 1)
    const brutEst = tib + cti + veil + iade + jma + dimJf

    if (this.hasSidebarBrutTarget)
      this.sidebarBrutTarget.textContent = `${this.formatEuros(brutEst.toFixed(2))} €`
  }

  updateProgress() {
    const pct = Math.round((this.currentStepValue / 5) * 100)
    if (this.hasProgressFillTarget)    this.progressFillTarget.style.width = `${pct}%`
    if (this.hasConfidenceLabelTarget) this.confidenceLabelTarget.textContent = `Étape ${this.currentStepValue + 1} / 6`
  }

  updateTib() {
    const grade   = this.formTarget.querySelector("[name='simulation_session[grade]']")?.value || "grade1"
    const echelon = parseInt(this.formTarget.querySelector("[name='simulation_session[echelon]']")?.value) || 1
    const quotite = parseFloat(this.formTarget.querySelector("[name='simulation_session[quotite]']")?.value) || 1.0

    const im = this.GRILLE[grade]?.[echelon]
    if (!im) return

    const tib       = im * this.VALEUR_POINT * quotite
    const tauxH     = (tib * 12 / 1820).toFixed(4)    // taux horaire FPH (÷ 1820 h/an)
    const primeIade = (this.PRIME_IADE * quotite).toFixed(2)

    if (this.hasImDisplayTarget)          this.imDisplayTarget.value          = im
    if (this.hasTibDisplayTarget)         this.tibDisplayTarget.value         = `${this.formatEuros(tib.toFixed(2))} €`
    if (this.hasTauxHoraireDisplayTarget) this.tauxHoraireDisplayTarget.value = `${tauxH} €/h`
    if (this.hasSidebarTibTarget)         this.sidebarTibTarget.textContent   = `${this.formatEuros(tib.toFixed(2))} €`
    if (this.hasSidebarPrimeIadeTarget)   this.sidebarPrimeIadeTarget.textContent = `${this.formatEuros(primeIade)} €`

    this._tib     = tib
    this._quotite = quotite
    this.updateIr()
    this.updateSft()
    this.updateNbi()
  }

  // Valide tous les champs required du panel courant avant de passer à l'étape suivante
  _validateCurrentStep() {
    const panel = this.panelTargets.find(p => parseInt(p.dataset.step) === this.currentStepValue)
    if (!panel) return true

    const fields  = Array.from(panel.querySelectorAll("[required]"))
    const invalid = fields.filter(f => {
      if (f.type === "checkbox") return !f.checked
      return !f.value || f.value.trim() === ""
    })

    // Nettoyer les erreurs précédentes
    panel.querySelectorAll(".step-validation-error").forEach(el => el.remove())
    panel.querySelectorAll(".field-invalid").forEach(el => el.classList.remove("field-invalid"))

    if (invalid.length === 0) return true

    // Surligner les champs manquants
    invalid.forEach(f => f.closest(".field-group")?.classList.add("field-invalid"))

    // Afficher le bandeau d'erreur au-dessus des boutons
    const footer = panel.querySelector(".panel-footer")
    const errDiv = document.createElement("div")
    errDiv.className = "alert alert--error step-validation-error"
    errDiv.style.marginBottom = "0.75rem"
    const labels = invalid.map(f => {
      const lbl = panel.querySelector(`label[for="${f.id}"]`)
      return lbl ? lbl.textContent.replace(/[*✱]/g, "").trim() : "un champ obligatoire"
    })
    const unique = [...new Set(labels)]
    errDiv.textContent = `Champ${unique.length > 1 ? "s" : ""} obligatoire${unique.length > 1 ? "s" : ""} manquant${unique.length > 1 ? "s" : ""} : ${unique.join(", ")}.`
    footer.before(errDiv)
    return false
  }

  formatEuros(value) {
    return parseFloat(value).toLocaleString("fr-FR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  }
}
