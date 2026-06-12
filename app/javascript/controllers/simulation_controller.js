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

  VALEUR_POINT = 4.92284
  PRIME_IADE   = 485.72

  GRILLE = {
    grade1: { 1:340, 2:358, 3:379, 4:405, 5:430, 6:458, 7:487, 8:514, 9:541, 10:566, 11:583 },
    grade2: { 1:517, 2:536, 3:556, 4:577, 5:598, 6:618, 7:638, 8:659, 9:680, 10:700, 11:718 }
  }

  IR_ZONES = {
    "75":1, "92":1, "93":1, "94":1,
    "77":2, "78":2, "91":2, "95":2
  }

  IR_TAUX = { 1: 0.03, 2: 0.01, 3: 0.00 }

  connect() {
    this.goto(this.currentStepValue)
    this.updateDates()
  }

  nextStep(e) {
    e.preventDefault()
    if (this.currentStepValue < 5) this.goto(this.currentStepValue + 1)
  }

  prevStep(e) {
    e.preventDefault()
    if (this.currentStepValue > 0) this.goto(this.currentStepValue - 1)
  }

  goto(step) {
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

    window.scrollTo({ top: 0, behavior: "smooth" })
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

  updateTib() {
    const grade   = this.formTarget.querySelector("[name='simulation_session[grade]']")?.value || "grade1"
    const echelon = parseInt(this.formTarget.querySelector("[name='simulation_session[echelon]']")?.value) || 1
    const quotite = parseFloat(this.formTarget.querySelector("[name='simulation_session[quotite]']")?.value) || 1.0

    const im = this.GRILLE[grade]?.[echelon]
    if (!im) return

    const tib       = (im * this.VALEUR_POINT * quotite).toFixed(2)
    const tauxH     = (parseFloat(tib) / 151.67).toFixed(4)
    const primeIade = (this.PRIME_IADE * quotite).toFixed(2)

    if (this.hasImDisplayTarget)          this.imDisplayTarget.value          = im
    if (this.hasTibDisplayTarget)         this.tibDisplayTarget.value         = `${this.formatEuros(tib)} €`
    if (this.hasTauxHoraireDisplayTarget) this.tauxHoraireDisplayTarget.value = `${tauxH} €/h`
    if (this.hasSidebarTibTarget)         this.sidebarTibTarget.textContent   = `${this.formatEuros(tib)} €`
    if (this.hasSidebarPrimeIadeTarget)   this.sidebarPrimeIadeTarget.textContent = `${this.formatEuros(primeIade)} €`

    this._tib = parseFloat(tib)
    this.updateIr()
    this.updateSft()
    this.updateNbi()
  }

  formatEuros(value) {
    return parseFloat(value).toLocaleString("fr-FR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  }

}
