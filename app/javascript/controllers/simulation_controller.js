import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "panel", "stepper",
    "moisPaie", "moisM", "moisM1", "moisM2",
    "imDisplay", "tibDisplay", "tauxHoraireDisplay",
    "progressFill", "confidenceLabel",
    "form", "zoneDisplay", "irDisplay", "sftDisplay", "nbiDisplay"
  ]

  static values = {
    currentStep: { type: Number, default: 0 }
  }

  // ── Constantes métier ──────────────────────────────────────────
  VALEUR_POINT = 4.92278
  CTI_POINTS   = 49
  PRIME_VEIL   = 90.00
  PRIME_IADE   = 180.00

  GRILLE = {
    grade1: { 1:450, 2:478, 3:506, 4:534, 5:563, 6:593, 7:624, 8:656, 9:690, 10:727 },
    grade2: { 1:558, 2:582, 3:615, 4:648, 5:681, 6:714, 7:743, 8:769 }
  }

  MAX_ECHELON = { grade1: 10, grade2: 8 }

  IR_ZONES = { "75":1, "92":1, "93":1, "94":1, "77":2, "78":2, "91":2, "95":2 }
  IR_TAUX  = { 1: 0.03, 2: 0.01, 3: 0.00 }

  // ── Lifecycle ─────────────────────────────────────────────────
  connect() {
    this._render(this.currentStepValue)
    this.updateDates()
    this.updateTib()
    this.updateProgress()
  }

  // ── Navigation ────────────────────────────────────────────────
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
      panel.classList.toggle("hidden", parseInt(panel.dataset.step) !== step)
    })

    this.element.querySelectorAll(".step-item").forEach((btn, i) => {
      btn.classList.remove("is-active", "is-done")
      if (i === step)     btn.classList.add("is-active")
      else if (i < step) btn.classList.add("is-done")
    })

    this.element.querySelectorAll(".step-validation-error").forEach(el => el.remove())
    this.element.querySelectorAll(".field-invalid").forEach(el => el.classList.remove("field-invalid"))

    window.scrollTo({ top: 0, behavior: "smooth" })
    this.updateProgress()
  }

  // ── Dates ─────────────────────────────────────────────────────
  updateDates() {
    const raw = this.hasMoisPaieTarget ? this.moisPaieTarget.value : null
    if (!raw) return
    const [year, month] = raw.split("-").map(Number)
    const toValue = d => `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,"0")}`
    if (this.hasMoisMTarget)  this.moisMTarget.value  = toValue(new Date(year, month-1, 1))
    if (this.hasMoisM1Target) this.moisM1Target.value = toValue(new Date(year, month-2, 1))
    if (this.hasMoisM2Target) this.moisM2Target.value = toValue(new Date(year, month-3, 1))
  }

  // ── Changement de grade ───────────────────────────────────────
  gradeChanged(e) {
    const grade  = e.target.value
    const maxEch = this.MAX_ECHELON[grade] || 11
    const sel    = this.formTarget.querySelector("[name='simulation_session[echelon]']")
    if (!sel) return
    const cur = parseInt(sel.value) || 1
    sel.innerHTML = ""
    for (let i = 1; i <= maxEch; i++) {
      const opt = document.createElement("option")
      opt.value = i; opt.textContent = i
      if (i === Math.min(cur, maxEch)) opt.selected = true
      sel.appendChild(opt)
    }
    this.updateTib()
  }

  // ── Mises à jour des affichages dans le formulaire ────────────
  updateTib() {
    const grade   = this._fv("grade")   || "grade1"
    const echelon = parseInt(this._fv("echelon")) || 1
    const quotite = parseFloat(this._fv("quotite")) || 1.0
    const im      = this.GRILLE[grade]?.[echelon]
    if (!im) return

    const tib   = im * this.VALEUR_POINT * quotite
    const tauxH = (tib * 12 / 1820).toFixed(4)

    if (this.hasImDisplayTarget)          this.imDisplayTarget.value          = im
    if (this.hasTibDisplayTarget)         this.tibDisplayTarget.value         = `${this.fmt(tib)} €`
    if (this.hasTauxHoraireDisplayTarget) this.tauxHoraireDisplayTarget.value = `${tauxH} €/h`

    this.updateSidebar()
  }

  updateIr() {
    const dept  = this._fv("departement_code") || "75"
    const tib   = parseFloat(this._fv_tib()) || 0
    const zone  = this.IR_ZONES[dept] || 3
    const taux  = this.IR_TAUX[zone] || 0
    const ir    = (tib * taux).toFixed(2)

    if (this.hasZoneDisplayTarget)
      this.zoneDisplayTarget.value = `Zone ${zone} — ${(taux*100).toFixed(0)}% du TIB`
    if (this.hasIrDisplayTarget)
      this.irDisplayTarget.value = `${this.fmt(ir)} €`

    this.updateSidebar()
  }

  updateSft() {
    const nb       = parseInt(this._fv("nb_enfants_sft")) || 0
    const tib      = this._fv_tib() || 0
    const alternee = this._fv("garde_alternee") === "true"
    let sft = this._calcSft(nb, tib, alternee)

    if (this.hasSftDisplayTarget)
      this.sftDisplayTarget.value = `${this.fmt(sft.toFixed(2))} €`
    this.updateSidebar()
  }

  updateNbi() {
    const pts = parseInt(this._fv("nbi_points")) || 0
    const nbi = (pts * this.VALEUR_POINT).toFixed(2)
    if (this.hasNbiDisplayTarget) this.nbiDisplayTarget.value = `${this.fmt(nbi)} €`
    this.updateSidebar()
  }

  updateProgress() {
    const pct = Math.round((this.currentStepValue / 5) * 100)
    if (this.hasProgressFillTarget)    this.progressFillTarget.style.width = `${pct}%`
    if (this.hasConfidenceLabelTarget) this.confidenceLabelTarget.textContent = `Étape ${this.currentStepValue + 1} / 6`
  }

  // ── SIDEBAR TEMPS RÉEL ────────────────────────────────────────
  updateSidebar() {
    const grade    = this._fv("grade")    || "grade1"
    const echelon  = parseInt(this._fv("echelon")) || 1
    const quotite  = parseFloat(this._fv("quotite")) || 1.0
    const statut   = this._fv("statut")   || "titulaire"
    const dept     = this._fv("departement_code") || "75"
    const nbiPts   = parseInt(this._fv("nbi_points")) || 0
    const nbEnf    = parseInt(this._fv("nb_enfants_sft")) || 0
    const alternee = this._fv("garde_alternee") === "true"
    const tausPas  = parseFloat(this._fv("taux_pas")) || 0
    const mutuelle = parseFloat(this._fv("mutuelle")) || 0
    const hNuit    = parseFloat(this._fv("heures_nuit")) || 0
    const hDim     = parseFloat(this._fv("heures_dimanche")) || 0
    const hFerie   = parseFloat(this._fv("heures_ferie")) || 0
    const hsJour   = parseFloat(this._fv("hs_jour")) || 0
    const hsNuit   = parseFloat(this._fv("hs_nuit")) || 0
    const hsDimJf  = parseFloat(this._fv("hs_dim_jf")) || 0

    // ── Traitements fixes ──
    const im  = this.GRILLE[grade]?.[echelon] || 0
    const tib = im * this.VALEUR_POINT * quotite
    const cti = this.CTI_POINTS * this.VALEUR_POINT * quotite
    const veil = this.PRIME_VEIL * quotite
    const iade = this.PRIME_IADE * quotite
    const iba  = statut === "contractuel" ? 0 : (389 * quotite / 12)

    const zone   = this.IR_ZONES[dept] || 3
    const tauxIr = this.IR_TAUX[zone] || 0
    const ir     = tib * tauxIr
    const irNbi  = (nbiPts * this.VALEUR_POINT * quotite) * tauxIr
    const nbi    = nbiPts * this.VALEUR_POINT * quotite
    const iss    = (13 / 1900) * 12 * (tib + ir)
    const sft    = this._calcSft(nbEnf, tib, alternee)

    // ── Planning ──
    const baseH  = (tib + ir) * 12 / 1820
    const jma    = baseH * 0.25 * hNuit
    const dimjf  = (hDim + hFerie) * 7.50
    const hsTotal = baseH * (hsJour * 1.26 + hsNuit * 2.52 + hsDimJf * 2.10)

    // ── Brut ──
    const brut = tib + cti + veil + iade - iba + ir + nbi + irNbi + iss + sft + jma + dimjf + hsTotal

    // ── Cotisations estimées ──
    let cnracl = 0, rafp = 0
    if (statut !== "contractuel") {
      cnracl = 0.111 * (tib + cti)
      if (nbiPts > 0) cnracl += 0.111 * nbi
      const primesApresIba = Math.max(0, cti + veil + iade - iba + iss + jma + dimjf)
      const plafondRafp    = tib * 12 * 0.20
      rafp = Math.min(primesApresIba, plafondRafp) * 0.05
    } else {
      cnracl = 0.0401 * (tib + cti + brut)   // IRCANTEC approximation
    }
    const baseCsg  = brut * 0.9825
    const csgTotal = baseCsg * (0.029 + 0.068) + (hsTotal > 0 ? hsTotal * 0.068 : 0)
    const totalAv  = cnracl + rafp + csgTotal
    const netAvPas = brut - totalAv
    const pas      = netAvPas * (tausPas / 100)
    const net      = netAvPas - pas - mutuelle

    // ── Mise à jour du DOM ──
    this._sbAmt("tib",    tib)
    this._sbAmt("cti",    cti)
    this._sbAmt("veil",   veil)
    this._sbAmt("iade",   iade)
    this._sbNeg("iba",    iba,    statut !== "contractuel")
    this._sbAmt("ir",     ir)
    this._sbAmt("iss",    iss)

    if (nbiPts > 0) {
      this._sbAmt("nbi", nbi)
      this._sbLineShow("nbi", true)
    } else {
      this._sbLineShow("nbi", false)
    }

    if (nbEnf > 0 && sft > 0) {
      this._sbAmt("sft", sft)
      this._sbLineShow("sft", true)
    } else {
      this._sbLineShow("sft", false)
    }

    const hasPlanning = jma > 0 || dimjf > 0 || hsTotal > 0
    this._sbLineShow("planning", hasPlanning)
    this._sbLineShow("jma",   jma   > 0); if (jma   > 0) this._sbAmt("jma",   jma)
    this._sbLineShow("dimjf", dimjf > 0); if (dimjf > 0) this._sbAmt("dimjf", dimjf)
    this._sbLineShow("hs",    hsTotal > 0); if (hsTotal > 0) this._sbAmt("hs", hsTotal)

    this._sbTotal("brut",   brut)
    this._sbNeg("cnracl",   cnracl + rafp, true)
    this._sbNeg("csg",      csgTotal,      true)
    this._sbNeg("pas",      pas,           tausPas > 0)
    this._sbTotal("net",    net)
  }

  // ── Validation par étape ──────────────────────────────────────
  _validateCurrentStep() {
    const panel = this.panelTargets.find(p => parseInt(p.dataset.step) === this.currentStepValue)
    if (!panel) return true
    const invalid = Array.from(panel.querySelectorAll("[required]")).filter(f =>
      f.type === "checkbox" ? !f.checked : !f.value || f.value.trim() === ""
    )
    panel.querySelectorAll(".step-validation-error").forEach(el => el.remove())
    panel.querySelectorAll(".field-invalid").forEach(el => el.classList.remove("field-invalid"))
    if (invalid.length === 0) return true

    invalid.forEach(f => f.closest(".field-group")?.classList.add("field-invalid"))
    const labels = [...new Set(invalid.map(f => {
      const lbl = panel.querySelector(`label[for="${f.id}"]`)
      return lbl ? lbl.textContent.replace(/[*✱]/g,"").trim() : "champ obligatoire"
    }))]
    const errDiv = document.createElement("div")
    errDiv.className = "alert alert--error step-validation-error"
    errDiv.style.marginBottom = "0.75rem"
    errDiv.textContent = `Champ${labels.length>1?"s":""} obligatoire${labels.length>1?"s":""} manquant${labels.length>1?"s":""} : ${labels.join(", ")}.`
    panel.querySelector(".panel-footer").before(errDiv)
    return false
  }

  // ── Helpers ───────────────────────────────────────────────────

  _fv(name) {
    return this.formTarget.querySelector(`[name='simulation_session[${name}]']`)?.value
  }

  _fv_tib() {
    const grade   = this._fv("grade")   || "grade1"
    const echelon = parseInt(this._fv("echelon")) || 1
    const quotite = parseFloat(this._fv("quotite")) || 1.0
    const im      = this.GRILLE[grade]?.[echelon] || 0
    return im * this.VALEUR_POINT * quotite
  }

  _calcSft(nb, tib, alternee) {
    let sft = 0
    if (nb === 1)      sft = 2.29
    else if (nb === 2) sft = Math.max(73.04, 10.67 + tib * 0.03)
    else if (nb >= 3)  sft = Math.max(181.56 + (nb-3)*129.10, 15.24 + tib*0.08 + (nb-3)*(4.57 + tib*0.06))
    return alternee && sft > 0 ? sft / 2 : sft
  }

  // Montant positif dans la sidebar
  _sbAmt(id, value) {
    const el = this.element.querySelector(`[data-sb="${id}"]`)
    if (!el) return
    if (value > 0.005) {
      el.textContent = this.fmt(value.toFixed(2)) + " €"
      el.classList.add("is-set")
    } else {
      el.textContent = "—"
      el.classList.remove("is-set")
    }
  }

  // Montant négatif (cotisation ou déduction)
  _sbNeg(id, value, show) {
    const el = this.element.querySelector(`[data-sb="${id}"]`)
    if (!el) return
    if (show && value > 0.005) {
      el.textContent = "−" + this.fmt(value.toFixed(2)) + " €"
      el.classList.add("is-set")
    } else {
      el.textContent = "—"
      el.classList.remove("is-set")
    }
  }

  // Total brut ou net
  _sbTotal(id, value) {
    const el = this.element.querySelector(`[data-sb="${id}"]`)
    if (!el) return
    if (value > 0.005) {
      el.textContent = this.fmt(value.toFixed(2)) + " €"
      el.classList.add("is-set")
    } else {
      el.textContent = "—"
      el.classList.remove("is-set")
    }
  }

  // Affiche / masque une ligne ou section conditionnelle
  _sbLineShow(id, visible) {
    const el = this.element.querySelector(`[data-sb-line="${id}"]`)
    if (el) el.classList.toggle("hidden", !visible)
  }

  fmt(value) {
    return parseFloat(value).toLocaleString("fr-FR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  }
}
