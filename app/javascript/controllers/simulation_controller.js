import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "panel", "stepper",
    "moisPaie", "moisM", "moisM1", "moisM2",
    "imDisplay", "tibDisplay", "tauxHoraireDisplay",
    "progressFill", "confidenceLabel",
    "form", "zoneDisplay", "irDisplay", "sftDisplay", "nbiDisplay",
    "gradeSelect", "dtcMontantRow",
    "wt1NspHint", "wt1DetailRows", "navigoZonesRow", "navigoAutreRow", "wt1Display",
    "fmdRow", "fmdEstimate",
    "xrnNuitsRow", "xrnNspHint", "xrnInfoDisplay",
    "selfRepasRow", "selfDisplay",
    "absencesList", "absenceCard", "absenceTemplate", "absencesSummary",
    "ft1SemainesRow", "ft1MontantRow", "ft9MontantRow",
    "carriereEchelonActuel", "carriereTibActuelSub",
    "carriereBlockSuivant", "carriereEchelonSuivant", "carriereDeltaTibSub",
    "carriereBlockDate", "carriereDateEstimee", "carriereMoisRestantsSub",
    "carriereBlockTerminal", "carriereNoDateHint",
    "bulletinInput", "extractBanner", "realLineField", "realBrutField", "realNetField",
    "cycleCoherenceWarning", "pasReveal", "pasBlock"
  ]

  static values = {
    currentStep: { type: Number, default: 0 }
  }

  // ── Constantes métier ──────────────────────────────────────────
  VALEUR_POINT = 4.92278
  ABATTEMENT_FRAIS_PRO = 0.9825
  CTI_POINTS   = 49
  PRIME_VEIL   = 90.00
  PRIME_IADE   = 180.00

  // Self de jour — table AP-HP de référence, note D2023-285, effet 01/03/2023.
  // Coût informatif uniquement (jamais déduit du net) — cf. SelfDeJourCalculator côté serveur.
  SELF_TARIFS = [
    { max: 353, tarif: 2.82 }, { max: 379, tarif: 3.48 }, { max: 463, tarif: 4.36 },
    { max: 534, tarif: 5.28 }, { max: 642, tarif: 6.26 }, { max: null, tarif: 7.36 }
  ]

  // Tarifs Navigo annuels Île-de-France Mobilités 2026 — cf. WT1_ZONES_TABLE côté serveur.
  WT1_ZONES = { "1-5": 998.80, "2-3": 976.80, "3-4": 950.40, "4-5": 928.40 }

  GRILLE = {
    grade1:    { 1:450, 2:478, 3:506, 4:534, 5:563, 6:593, 7:624, 8:656, 9:690, 10:727 },
    grade2:    { 1:558, 2:582, 3:615, 4:648, 5:681, 6:714, 7:743, 8:769 },
    as_grade1: { 1:373, 2:375, 3:377, 4:388, 5:401, 6:414, 7:429, 8:444, 9:461, 10:485, 11:517 },
    as_grade2: { 1:387, 2:399, 3:411, 4:424, 5:442, 6:460, 7:480, 8:499, 9:519, 10:539, 11:560 },
    ide_grade1:{ 1:376, 2:394, 3:413, 4:439, 5:466, 6:496, 7:527, 8:553, 9:578, 10:610 },
    ide_grade2:{ 1:446, 2:463, 3:487, 4:514, 5:543, 6:572, 7:601, 8:626 }
  }

  MAX_ECHELON = { grade1: 10, grade2: 8, as_grade1: 11, as_grade2: 11, ide_grade1: 10, ide_grade2: 8 }

  // Durée minimale en mois par échelon avant avancement (Décret n° 2012-1483) — miroir de CarriereCalculator
  DUREES = {
    grade1:     { 1:12, 2:24, 3:24, 4:24, 5:24, 6:24, 7:24, 8:36, 9:48, 10:null },
    grade2:     { 1:12, 2:24, 3:24, 4:24, 5:30, 6:36, 7:48, 8:null },
    as_grade1:  { 1:18, 2:18, 3:24, 4:24, 5:30, 6:36, 7:36, 8:36, 9:36, 10:48, 11:null },
    as_grade2:  { 1:18, 2:24, 3:24, 4:24, 5:24, 6:30, 7:36, 8:36, 9:36, 10:48, 11:null },
    ide_grade1: { 1:12, 2:24, 3:24, 4:30, 5:36, 6:36, 7:36, 8:48, 9:48, 10:null },
    ide_grade2: { 1:12, 2:24, 3:24, 4:24, 5:36, 6:36, 7:48, 8:null }
  }

  GRADE_OPTIONS = {
    iade: [["1er grade", "grade1"], ["2ème grade", "grade2"]],
    as:   [["Classe normale", "as_grade1"], ["Classe supérieure", "as_grade2"]],
    ide:  [["Grade normal", "ide_grade1"], ["Classe supérieure", "ide_grade2"]]
  }

  IR_ZONES = { "75":1, "92":1, "93":1, "94":1, "77":2, "78":2, "91":2, "95":2 }
  IR_TAUX  = { 1: 0.03, 2: 0.01, 3: 0.00 }

  // Amplitude horaire (fin - début) attendue par type de cycle. "7h36" est confirmée par la
  // paire d'horaires par défaut du formulaire (07:36→19:12 = 11h36) ; les 3 autres sont
  // extrapolées sur le même principe (poste + pause) faute de référence AP-HP disponible
  // dans ce dépôt — à confirmer/ajuster si besoin.
  CYCLE_AMPLITUDE_HEURES = { "7h36": 11.6, "7h30": 11.5, "10h": 10.5, "12h": 12.5 }
  CYCLE_TOLERANCE_HEURES = 0.25

  // ── Lifecycle ─────────────────────────────────────────────────
  connect() {
    this._render(this.currentStepValue)
    this.updateDates()
    this._initGradeOptions()
    this.updateTib()
    this.updateProgress()
    this.absenceCardTargets.forEach(card => this._syncAbsenceCard(card))
    this.updateAbsences()
    this._applyVisibility()
  }

  // ── Navigation ────────────────────────────────────────────────
  nextStep(e) {
    e.preventDefault()
    if (!this._validateCurrentStep()) return
    if (this.currentStepValue < 6) this._render(this.currentStepValue + 1)
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
    const fmt = new Intl.DateTimeFormat("fr-FR", { month: "long", year: "numeric" })
    const toLabel = d => {
      const s = fmt.format(d)
      return s.charAt(0).toUpperCase() + s.slice(1)
    }
    if (this.hasMoisMTarget)  this.moisMTarget.value  = toLabel(new Date(year, month-1, 1))
    if (this.hasMoisM1Target) this.moisM1Target.value = toLabel(new Date(year, month-2, 1))
    if (this.hasMoisM2Target) this.moisM2Target.value = toLabel(new Date(year, month-3, 1))
  }

  // ── Changement de profession ──────────────────────────────────
  professionChanged(e) {
    this._initGradeOptions(e.target.value)
    this.updateTib()
    this._applyVisibility()
  }

  // ── Prélèvement à la source (facultatif) ────────────────────────
  revealPasBlock() {
    if (this.hasPasBlockTarget) this.pasBlockTarget.classList.remove("hidden")
    if (this.hasPasRevealTarget) this.pasRevealTarget.classList.add("hidden")
  }

  // ── Cohérence cycle / horaires ──────────────────────────────────
  // Avertissement non bloquant, jamais pris en compte par _validateCurrentStep.
  checkCycleCoherence() {
    if (!this.hasCycleCoherenceWarningTarget) return
    const cycle = this._fv("type_cycle")
    const attendu = this.CYCLE_AMPLITUDE_HEURES[cycle]
    const debut = this._fv("heure_debut_service")
    const fin   = this._fv("heure_fin_service")
    if (!attendu || !debut || !fin) {
      this.cycleCoherenceWarningTarget.classList.add("hidden")
      return
    }
    const toHeures = (hhmm) => {
      const [h, m] = hhmm.split(":").map(Number)
      return h + m / 60
    }
    let amplitude = toHeures(fin) - toHeures(debut)
    if (amplitude < 0) amplitude += 24 // passage minuit (poste de nuit)
    const coherent = Math.abs(amplitude - attendu) <= this.CYCLE_TOLERANCE_HEURES
    this.cycleCoherenceWarningTarget.classList.toggle("hidden", coherent)
  }

  // ── Mode standard / expert ─────────────────────────────────────
  // Non persisté (pas d'attribut modèle) : commodité d'UI uniquement, le moteur de calcul
  // ignore totalement ce qui est visible ou non côté formulaire.
  modeToggle() {
    this._applyVisibility()
  }

  _modeValue() {
    const checked = this.element.querySelector("input[data-mode-radio]:checked")
    return checked ? checked.value : "standard"
  }

  // Mécanisme de visibilité déclaratif générique : tout élément portant
  // data-visible-when="axe:valeur1,valeur2[;axe2:valeur3]" est affiché seulement si CHAQUE
  // condition (séparée par ;) est satisfaite (une valeur parmi celles listées pour son axe).
  // Axes supportés aujourd'hui : "mode" (standard/expert) et "profession" (iade/ide/as).
  _applyVisibility() {
    const context = { mode: this._modeValue(), profession: this._fv("profession") || "iade" }
    this.element.querySelectorAll("[data-visible-when]").forEach(el => {
      const conditions = el.dataset.visibleWhen.split(";")
      const visible = conditions.every(cond => {
        const [axis, values] = cond.split(":")
        return (values || "").split(",").includes(context[axis])
      })
      el.classList.toggle("hidden", !visible)
    })
  }

  _initGradeOptions(profession) {
    if (!this.hasGradeSelectTarget) return
    const prof    = profession || this._fv("profession") || "iade"
    const options = this.GRADE_OPTIONS[prof] || this.GRADE_OPTIONS.iade
    const current = this.gradeSelectTarget.value
    this.gradeSelectTarget.innerHTML = ""
    options.forEach(([label, value]) => {
      const opt = document.createElement("option")
      opt.value = value
      opt.textContent = label
      if (value === current) opt.selected = true
      this.gradeSelectTarget.appendChild(opt)
    })
    if (!this.gradeSelectTarget.value) {
      this.gradeSelectTarget.options[0].selected = true
    }
    this._updateEchelonMax()
  }

  // ── Changement de grade ───────────────────────────────────────
  gradeChanged(e) {
    this._updateEchelonMax()
    this.updateTib()
  }

  _updateEchelonMax() {
    const grade  = this._fv("grade") || "grade1"
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

  dtcToggle(e) {
    if (!this.hasDtcMontantRowTarget) return
    const show = e.target.value === "oui"
    this.dtcMontantRowTarget.style.display = show ? "" : "none"
    if (!show) {
      const input = this.dtcMontantRowTarget.querySelector("input")
      if (input) input.value = ""
    }
    this.updateSidebar()
  }

  ft1ModeToggle(e) {
    const montant = e.target.value === "montant"
    if (this.hasFt1SemainesRowTarget) this.ft1SemainesRowTarget.style.display = montant ? "none" : ""
    if (this.hasFt1MontantRowTarget)  this.ft1MontantRowTarget.style.display  = montant ? "" : "none"
    this.updateSidebar()
  }

  ft9Toggle(e) {
    if (!this.hasFt9MontantRowTarget) return
    const show = e.target.value === "1"
    this.ft9MontantRowTarget.style.display = show ? "" : "none"
    this.updateSidebar()
  }

  xrnEligibleToggle(e) {
    const value = e.target.value
    if (this.hasXrnNuitsRowTarget) this.xrnNuitsRowTarget.style.display = value === "oui" ? "" : "none"
    if (this.hasXrnNspHintTarget)  this.xrnNspHintTarget.style.display  = value === "nsp" ? "" : "none"
    if (value !== "oui") {
      const input = this.hasXrnNuitsRowTarget ? this.xrnNuitsRowTarget.querySelector("input") : null
      if (input) input.value = ""
    }
    this.updateSidebar()
  }

  selfEligibleToggle(e) {
    const value = e.target.value
    if (this.hasSelfRepasRowTarget) this.selfRepasRowTarget.style.display = value === "oui" ? "" : "none"
    if (value !== "oui") {
      const input = this.hasSelfRepasRowTarget ? this.selfRepasRowTarget.querySelector("input[type=number]") : null
      if (input) input.value = ""
    }
    this.updateSidebar()
  }

  wt1AbonnementToggle(e) {
    const value = e.target.value
    if (this.hasWt1DetailRowsTarget) this.wt1DetailRowsTarget.style.display = value === "oui" ? "" : "none"
    if (this.hasWt1NspHintTarget)    this.wt1NspHintTarget.style.display    = value === "nsp" ? "" : "none"
    this.updateSidebar()
  }

  navigoTypeToggle(e) {
    const autre = e.target.value === "autre"
    if (this.hasNavigoZonesRowTarget) this.navigoZonesRowTarget.style.display = autre ? "none" : ""
    if (this.hasNavigoAutreRowTarget) this.navigoAutreRowTarget.style.display = autre ? "" : "none"
    this.updateSidebar()
  }

  fmdToggle(e) {
    const show = e.target.value === "1"
    if (this.hasFmdRowTarget) this.fmdRowTarget.style.display = show ? "" : "none"
    this.updateFmd()
  }

  updateFmd() {
    const jours = parseInt(this._fv("fmd_jours_annee")) || 0
    let fmd = 0
    if (jours >= 30) {
      if (jours < 60)       fmd = 100
      else if (jours < 100) fmd = 200
      else                  fmd = 300
    }
    if (this.hasFmdEstimateTarget) {
      this.fmdEstimateTarget.textContent = fmd > 0
        ? `Estimation FMD : ${fmd} € (versé oct./nov. N+1)`
        : jours > 0 ? "Moins de 30 jours — FMD non déclenché." : ""
    }
  }

  // ── Absences ──────────────────────────────────────────────────
  addAbsence(e) {
    e.preventDefault()
    const fragment = this.absenceTemplateTarget.content.cloneNode(true)
    this.absencesListTarget.appendChild(fragment)
    this._renumberAbsences()
    this.updateAbsences()
  }

  removeAbsence(e) {
    e.preventDefault()
    const card = e.target.closest('[data-simulation-target~="absenceCard"]')
    if (card) card.remove()
    this._renumberAbsences()
    this.updateAbsences()
  }

  absenceChanged(e) {
    const card = e.target.closest('[data-simulation-target~="absenceCard"]')
    if (card) this._syncAbsenceCard(card)
    this.updateAbsences()
  }

  _renumberAbsences() {
    this.absenceCardTargets.forEach((card, i) => {
      const label = card.querySelector('[data-role="absence-index"]')
      if (label) label.textContent = `n°${i + 1}`
    })
  }

  // Affiche/masque les questions 3/4 (maladie ordinaire), 5 (imputabilité) et 6 (palier CLM/CLD)
  _syncAbsenceCard(card) {
    const typeSelect = card.querySelector(".absence-field--type")
    const family = typeSelect?.selectedOptions[0]?.dataset.family
    const isProlongationType = typeSelect?.value === "prolongation_maladie_ordinaire"
    const isMaladieOrdinaire = family === "maladie_ordinaire"
    const isImputabilite = family === "imputabilite"
    const isLongueMaladie = family === "longue_maladie"
    const q3 = card.querySelector(".absence-q3")
    const q4 = card.querySelector(".absence-q4")
    const q5 = card.querySelector(".absence-q5")
    const q6 = card.querySelector(".absence-q6")
    if (q3) q3.style.display = (isMaladieOrdinaire && !isProlongationType) ? "" : "none"
    if (q4) q4.style.display = isMaladieOrdinaire ? "" : "none"
    if (q5) q5.style.display = isImputabilite ? "" : "none"
    if (q6) q6.style.display = isLongueMaladie ? "" : "none"
  }

  _parseDateInput(value) {
    if (!value) return null
    const [y, m, d] = value.split("-").map(Number)
    if (!y || !m || !d) return null
    return new Date(Date.UTC(y, m - 1, d))
  }

  // Calcule (en aperçu) jours de carence / CMO 90% / CMO 50% à partir des absences saisies.
  // Le calcul faisant foi reste côté serveur (Iade::AbsenceEntriesResolver).
  updateAbsences() {
    const moisPaie = this._fv("mois_paie") || ""
    const [y, m] = moisPaie.split("-").map(Number)
    const monthStart = (y && m) ? new Date(Date.UTC(y, m - 1, 1)) : null
    const monthEnd   = (y && m) ? new Date(Date.UTC(y, m, 0)) : null

    let carence = 0, cmo90 = 0, cmo50 = 0, maintenu100 = 0, nonCalcule = 0
    let clmCldPlein = 0, clmCldDemi = 0, anr = 0

    this.absenceCardTargets.forEach(card => {
      const resultEl = card.querySelector(".absence-field--result")
      const debut = this._parseDateInput(card.querySelector(".absence-field--debut")?.value)
      const fin   = this._parseDateInput(card.querySelector(".absence-field--fin")?.value)

      if (!debut || !fin || !monthStart || fin < debut) {
        if (resultEl) resultEl.value = "—"
        return
      }

      const clipDebut = debut > monthStart ? debut : monthStart
      const clipFin   = fin   < monthEnd   ? fin   : monthEnd
      if (clipFin < clipDebut) {
        if (resultEl) resultEl.value = "0 j (hors mois simulé)"
        return
      }

      const joursInMonth = Math.round((clipFin - clipDebut) / 86400000) + 1
      const typeSelect = card.querySelector(".absence-field--type")
      const family = typeSelect?.selectedOptions[0]?.dataset.family

      const applyMaladieOrdinaire = (continuationOverride, compteurOverride) => {
        const isProlongationType = typeSelect.value === "prolongation_maladie_ordinaire"
        const continuation = continuationOverride || (isProlongationType
          ? "prolongation"
          : (card.querySelector(".absence-field--continuation")?.value || "nouvel_arret"))
        const carenceApplies = !["prolongation", "reprise_48h"].includes(continuation)
        const carenceDays = (carenceApplies && debut >= monthStart) ? Math.min(1, joursInMonth) : 0
        const remaining = joursInMonth - carenceDays
        const compteur = compteurOverride || (card.querySelector(".absence-field--compteur")?.value || "non")

        carence += carenceDays
        if (compteur === "oui") { cmo50 += remaining } else { cmo90 += remaining }

        if (resultEl) {
          const parts = []
          if (carenceDays > 0) parts.push(`${carenceDays}j carence`)
          if (remaining > 0)   parts.push(`${remaining}j à ${compteur === "oui" ? "50%" : "90%"}`)
          resultEl.value = parts.length ? parts.join(" · ") : "—"
        }
      }

      if (family === "maladie_ordinaire") {
        applyMaladieOrdinaire()
      } else if (family === "imputabilite") {
        const imputabilite = card.querySelector(".absence-field--imputabilite")?.value || "en_attente"
        if (imputabilite === "oui") {
          maintenu100 += joursInMonth
          if (resultEl) resultEl.value = `${joursInMonth}j maintenus à 100% (imputabilité reconnue)`
        } else {
          applyMaladieOrdinaire("nouvel_arret", "non")
          if (resultEl) resultEl.value += " (provisoire, imputabilité non reconnue)"
        }
      } else if (family === "longue_maladie") {
        const palier = card.querySelector(".absence-field--palier")?.value || "demi"
        if (palier === "plein") {
          clmCldPlein += joursInMonth
          if (resultEl) resultEl.value = `${joursInMonth}j à plein traitement (primes coupées)`
        } else {
          clmCldDemi += joursInMonth
          if (resultEl) resultEl.value = `${joursInMonth}j à demi-traitement (primes coupées)`
        }
      } else if (family === "anr") {
        anr += joursInMonth
        if (resultEl) resultEl.value = `${joursInMonth}j — retenue intégrale`
      } else if (family === "maintenu_100") {
        maintenu100 += joursInMonth
        if (resultEl) resultEl.value = `${joursInMonth}j maintenus à 100%`
      } else {
        nonCalcule += joursInMonth
        if (resultEl) resultEl.value = `${joursInMonth}j — calcul non disponible`
      }
    })

    this._absenceTotals = { carence, cmo90, cmo50, clmCldPlein, clmCldDemi, anr, joursCalendaires: monthEnd ? monthEnd.getUTCDate() : 30 }

    if (this.hasAbsencesSummaryTarget) {
      const total = carence + cmo90 + cmo50 + maintenu100 + nonCalcule + clmCldPlein + clmCldDemi + anr
      if (total === 0) {
        this.absencesSummaryTarget.textContent = "Aucune absence saisie ce mois-ci."
      } else {
        const parts = [`${total}j au total`]
        if (carence)     parts.push(`${carence}j carence`)
        if (cmo90)       parts.push(`${cmo90}j à 90%`)
        if (cmo50)       parts.push(`${cmo50}j à 50%`)
        if (clmCldPlein) parts.push(`${clmCldPlein}j CLM/CLD plein`)
        if (clmCldDemi)  parts.push(`${clmCldDemi}j CLM/CLD demi`)
        if (anr)         parts.push(`${anr}j non rémunérés`)
        if (maintenu100) parts.push(`${maintenu100}j maintenus à 100%`)
        if (nonCalcule)  parts.push(`${nonCalcule}j non calculés`)
        this.absencesSummaryTarget.textContent = parts.join(" · ")
      }
    }

    this.updateSidebar()
  }

  updateProgress() {
    const pct = Math.round((this.currentStepValue / 6) * 100)
    if (this.hasProgressFillTarget)    this.progressFillTarget.style.width = `${pct}%`
    if (this.hasConfidenceLabelTarget) this.confidenceLabelTarget.textContent = `Étape ${this.currentStepValue + 1} / 7`
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
    const hJw0Regul = parseFloat(this._fv("jw0_regul_heures")) || 0
    const cumulHsAnt = parseFloat(this._fv("cumul_hs_brut_anterieur")) || 0
    const hsM2Nuit     = parseFloat(this._fv("hs_m2_nuit")) || 0
    const hsM2Dimanche = parseFloat(this._fv("hs_m2_dimanche")) || 0
    const hsM2Ferie    = parseFloat(this._fv("hs_m2_ferie")) || 0
    const hsM2Jour     = parseFloat(this._fv("hs_m2_jour")) || 0
    const tp7Heures    = parseFloat(this._fv("tp7_heures")) || 0
    const tp8Heures    = parseFloat(this._fv("tp8_heures")) || 0
    const mPsr     = parseFloat(this._fv("montant_psr")) || 0
    const jAbsPsr  = parseInt(this._fv("jours_absence_psr")) || 0
    const mLsu     = parseFloat(this._fv("montant_lsu")) || 0
    const mDiv     = parseFloat(this._fv("montant_primes_diverses")) || 0
    const ft1Mode  = this._fv("ft1_mode") || "semaines"
    const ft1Semaines = parseInt(this._fv("ft1_semaines")) || 0
    const ft1Montant  = parseFloat(this._fv("ft1_montant")) || 0
    const ft9Actif    = this._fv("ft9_actif") === "1"
    const ft9Montant  = parseFloat(this._fv("ft9_montant")) || 190
    const nbGardes    = parseFloat(this._fv("nb_gardes")) || 0
    const hGarde      = parseFloat(this._fv("heures_par_garde")) || 4
    const heuresWeekendGarde = parseFloat(this._fv("heures_weekend_garde")) || 0
    const { carence: joursCarence = 0, cmo90: joursCmo90 = 0, cmo50: joursCmo50 = 0 } = this._absenceTotals || {}
    const typeNavigo      = this._fv("type_navigo") || "mensuel"
    const wt1Abonnement   = this._fv("wt1_a_abonnement") || "non"
    const wt1Zones        = this._fv("wt1_zones") || ""
    const wt1NuitEligible = this._fv("wt1_nuit_eligible") || "non"
    const heureDebut      = this._fv("heure_debut_service") || "07:36"
    const isNuit = wt1NuitEligible === "oui" ? true
      : wt1NuitEligible === "non" ? false
      : heureDebut.slice(0, 5) >= "19:00"
    // tarif_annuel_ref = table_navigo_annee[zones] — référence unique quel que soit le pass
    // (annuel/mois/semaine) ; "autre abonnement" utilise le montant mensuel saisi directement.
    const tarifAnnuelRef = this.WT1_ZONES[wt1Zones] || (parseFloat(this._fv("navigo_montant_annuel")) || 0)
    const wt1Base = (typeNavigo !== "autre" && tarifAnnuelRef > 0)
      ? tarifAnnuelRef / 12
      : (parseFloat(this._fv("wt1_montant")) || 0)
    const simulateFmd  = this._fv("simulate_fmd") === "1"
    const fmdJours     = parseInt(this._fv("fmd_jours_annee")) || 0
    const moisPaie     = this._fv("mois_paie") || ""
    const moisNum      = parseInt(moisPaie.slice(-2)) || 0

    // ── Traitements fixes ──
    const profession = this._fv("profession") || "iade"
    const im  = this.GRILLE[grade]?.[echelon] || 0
    const tib = im * this.VALEUR_POINT * quotite
    const cti = this.CTI_POINTS * this.VALEUR_POINT * quotite
    // Prime Veil : IADE + IDE. Prime IADE (LPN) : IADE uniquement.
    const veil = (profession === "iade" || profession === "ide") ? this.PRIME_VEIL * quotite : 0
    const iade = profession === "iade" ? this.PRIME_IADE * quotite : 0
    const iba  = statut === "contractuel" ? 0 : (389 * quotite / 12)

    const zone   = this.IR_ZONES[dept] || 3
    const tauxIr = this.IR_TAUX[zone] || 0
    const ir     = tib * tauxIr
    const irNbi  = (nbiPts * this.VALEUR_POINT * quotite) * tauxIr
    const nbi    = nbiPts * this.VALEUR_POINT * quotite
    const iss    = (13 / 1900) * 12 * (tib + ir)
    const sft    = this._calcSft(nbEnf, tib, alternee)

    // ── Planning ──
    const baseH    = (tib + ir) * 12 / 1820
    const jma      = baseH * 0.25 * hNuit
    const dimjf    = (hDim + hFerie + hJw0Regul) * 7.50
    const hsNuitDetail  = this._calcHeuresSupM2(baseH, hsM2Nuit + nbGardes * hGarde, hsM2Dimanche, hsM2Ferie, hsM2Jour)
    const greffeMontant = this._tronquerTaux(baseH * 2.52) * tp7Heures + this._tronquerTaux(baseH * 2.10) * tp8Heures
    const hsSupMontant  = hsNuitDetail.nuit + hsNuitDetail.autres
    const hsTotal  = hsSupMontant + greffeMontant
    const tauxHsN  = this._tronquerTaux(baseH * 2.52)
    const gardes   = heuresWeekendGarde * tauxHsN
    // Part exonérée fiscalement (IT5/IT7/DHN/IT8/TP7/TP8/GAR) — sert uniquement à la base
    // Q60, jamais au net avant PAS (Complément simulateur PAS §1)
    const hsExonereesBrut = hsNuitDetail.nuit + hsNuitDetail.autres + greffeMontant + gardes

    // ── Primes variables ──
    const pertePsr = jAbsPsr > 0 ? mPsr * jAbsPsr / 140 : 0
    const psr      = Math.max(0, mPsr - pertePsr)
    const lsu      = mLsu
    const div      = mDiv
    const ft1      = ft1Mode === "montant" ? ft1Montant : ft1Semaines * 54
    const ft9      = ft9Actif ? ft9Montant : 0

    // ── Transport (WT1) — remboursement hors brut, ajouté après le net social ──
    const totalAbsence = joursCarence + joursCmo90 + joursCmo50
    let wt1 = 0
    if (wt1Abonnement !== "non" && wt1Base > 0 && totalAbsence <= 60) {
      wt1 = wt1Base * (isNuit ? 1.0 : 0.75)
      if (quotite < 0.5) wt1 /= 2
    }

    // ── Restauration de nuit (XRN) — retenue nette, hors cotisations sociales ──
    const xrnEligible = this._fv("xrn_eligible") === "oui"
    const xrnNbNuits   = parseInt(this._fv("xrn_nb_nuits")) || 0
    const xrn = xrnEligible ? xrnNbNuits * 2.40 : 0
    if (this.hasXrnInfoDisplayTarget) {
      this.xrnInfoDisplayTarget.value = (xrnEligible && xrnNbNuits > 0)
        ? `Ticket ${this.fmt((xrnNbNuits * 6.00).toFixed(2))} € (dont employeur ${this.fmt((xrnNbNuits * 3.60).toFixed(2))} €)`
        : "—"
    }

    // ── Self de jour — coût informatif uniquement, jamais déduit du net ──
    const selfEligible = this._fv("self_repas_eligible") === "oui"
    const selfNbRepas   = parseInt(this._fv("self_nb_repas")) || 0
    const selfTarif = this._tarifSelf(im)
    const selfCout   = selfEligible ? selfNbRepas * selfTarif : 0
    if (this.hasSelfDisplayTarget) {
      this.selfDisplayTarget.value = (selfEligible && selfNbRepas > 0)
        ? `${this.fmt(selfTarif.toFixed(2))} € / repas → ${this.fmt(selfCout.toFixed(2))} € (informatif)`
        : "—"
    }

    // ── FMD (versé oct./nov. seulement) ──
    let fmd = 0
    if (simulateFmd && fmdJours >= 30 && (moisNum === 10 || moisNum === 11)) {
      if (fmdJours < 60)       fmd = 100
      else if (fmdJours < 100) fmd = 200
      else                     fmd = 300
    }

    // ── Brut (WT1/XRN exclus : hors brut, hors cotisations — fiche corrective codeur 17/08/2026) ──
    const brut = tib + cti + veil + iade - iba + ir + nbi + irNbi + iss + sft +
                 jma + dimjf + hsTotal + gardes + psr + lsu + div + ft1 + ft9 + fmd

    // ── Absences (retenues approchées — détail exact sur bulletin) ──
    const { clmCldPlein = 0, clmCldDemi = 0, anr = 0, joursCalendaires = 30 } = this._absenceTotals || {}
    const retCarence  = joursCarence > 0 ? (tib + cti) * joursCarence / 30 : 0
    const retCmo90    = joursCmo90   > 0 ? (tib + cti) * 0.10 * joursCmo90 / 30 : 0
    const retCmo50    = joursCmo50   > 0 ? (tib + cti) * 0.50 * joursCmo50 / 30 : 0
    const clmCldJours = clmCldPlein + clmCldDemi
    const retClmCld   = clmCldJours > 0
      ? (iss + veil + iade) * clmCldJours / 30 + (tib + cti + ir) * 0.50 * clmCldDemi / 30
      : 0
    const retAnr      = anr > 0 ? brut * anr / joursCalendaires : 0
    const retAbsTotal = retCarence + retCmo90 + retCmo50 + retClmCld + retAnr

    // ── Cotisations estimées ──
    let cnracl = 0, rafp = 0
    if (statut !== "contractuel") {
      cnracl = 0.111 * (tib + cti)
      if (nbiPts > 0) cnracl += 0.111 * nbi
      const primesApresIba = Math.max(0, cti + veil + iade - iba + iss + jma + dimjf + hsTotal + psr + lsu + div + ft1 + ft9)
      const plafondRafp    = tib * 12 * 0.20
      rafp = Math.min(primesApresIba, plafondRafp) * 0.05
    } else {
      cnracl = 0.0401 * (tib + cti + brut)
    }
    const baseCsg  = brut * this.ABATTEMENT_FRAIS_PRO
    const ucbMontant = baseCsg * 0.029
    // Exonération fiscale des heures sup plafonnée à 7 500 €/an (art. 81 quater CGI) — pool
    // commun à UC8 et à la base Q60 (Complément simulateur PAS §1)
    const reliquatHs      = Math.max(0, 7500 - cumulHsAnt)
    const hsExonereesEffectif = Math.min(hsExonereesBrut, reliquatHs)
    // UC8 : donnée fiscale (base Q60 uniquement), jamais une retenue réelle sur le net avant PAS.
    // Gardé par le brut HS/gardes réel (régime VR7), assiette = part encore exonérée (plafonnée),
    // même abattement 98,25% que UCB/UCX avant application du taux 6,80%.
    const hsGardes   = hsSupMontant + gardes
    const uc8Montant = hsGardes > 0 ? hsExonereesEffectif * this.ABATTEMENT_FRAIS_PRO * 0.068 : 0
    const csgTotal   = baseCsg * (0.029 + 0.068)
    const totalAv    = cnracl + rafp + csgTotal
    const netSocial  = brut - totalAv - retAbsTotal
    const baseQ60    = netSocial + ucbMontant + uc8Montant - hsExonereesEffectif
    const pas        = baseQ60 * (tausPas / 100)
    // Net avant PAS : net social + WT1 (remb. transport) − XRN (retenue restau. nuit)
    const netAvPas   = netSocial + wt1 - xrn
    const net        = netAvPas - pas - mutuelle

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

    const hasPlanning = jma > 0 || dimjf > 0 || hsTotal > 0 || gardes > 0
    this._sbLineShow("planning", hasPlanning)
    this._sbLineShow("jma",    jma    > 0); if (jma    > 0) this._sbAmt("jma",    jma)
    this._sbLineShow("dimjf",  dimjf  > 0); if (dimjf  > 0) this._sbAmt("dimjf",  dimjf)
    this._sbLineShow("hs",     hsTotal > 0); if (hsTotal > 0) this._sbAmt("hs",   hsTotal)
    this._sbLineShow("gardes", gardes > 0); if (gardes > 0) this._sbAmt("gardes", gardes)

    const hasPrimesVar = psr > 0 || lsu > 0 || div > 0 || ft1 > 0 || ft9 > 0
    this._sbLineShow("primes-var", hasPrimesVar)
    this._sbLineShow("psr", psr > 0); if (psr > 0) this._sbAmt("psr", psr)
    this._sbLineShow("lsu", lsu > 0); if (lsu > 0) this._sbAmt("lsu", lsu)
    this._sbLineShow("div", div > 0); if (div > 0) this._sbAmt("div", div)
    this._sbLineShow("ft1", ft1 > 0); if (ft1 > 0) this._sbAmt("ft1", ft1)
    this._sbLineShow("ft9", ft9 > 0); if (ft9 > 0) this._sbAmt("ft9", ft9)

    this._sbLineShow("fmd", fmd > 0); if (fmd > 0) this._sbAmt("fmd", fmd)

    if (this.hasWt1DisplayTarget) {
      const nspVariante = (wt1NuitEligible === "nsp" && wt1 > 0)
        ? ` — variante 100% : ${this.fmt((wt1 / (isNuit ? 1.0 : 0.75) * 1.0).toFixed(2))} €`
        : ""
      this.wt1DisplayTarget.value = wt1 > 0
        ? `${this.fmt(wt1.toFixed(2))} € (${isNuit ? "100% nuit" : "75% jour"}${quotite < 0.5 ? " ÷2" : ""})${nspVariante}`
        : totalAbsence > 60 ? "0 € (>60j absence)" : "—"
    }

    const hasAbsences = retAbsTotal > 0
    this._sbLineShow("absences", hasAbsences)
    this._sbLineShow("carence", retCarence > 0); if (retCarence > 0) this._sbNeg("carence", retCarence, true)
    this._sbLineShow("cmo90",   retCmo90   > 0); if (retCmo90   > 0) this._sbNeg("cmo90",   retCmo90,   true)
    this._sbLineShow("cmo50",   retCmo50   > 0); if (retCmo50   > 0) this._sbNeg("cmo50",   retCmo50,   true)
    this._sbLineShow("clmcld",  retClmCld  > 0); if (retClmCld  > 0) this._sbNeg("clmcld",  retClmCld,  true)
    this._sbLineShow("anr",     retAnr     > 0); if (retAnr     > 0) this._sbNeg("anr",     retAnr,     true)

    this._sbTotal("brut",       brut)
    this._sbNeg("cnracl",       cnracl + rafp, true)
    this._sbNeg("csg",          csgTotal,      true)
    this._sbNeg("pas",          pas,           tausPas > 0)
    this._sbTotal("net-social", netSocial)

    this._sbLineShow("hors-brut", wt1 > 0 || xrn > 0)
    this._sbLineShow("wt1", wt1 > 0); if (wt1 > 0) this._sbAmt("wt1", wt1)
    this._sbLineShow("xrn", xrn > 0); if (xrn > 0) this._sbNeg("xrn", xrn, true)

    this._sbTotal("net", net)

    this.updateCarriere(grade, echelon, quotite, tauxIr)
  }

  // ── Carrière — prochain échelon (étape 6) ───────────────────────
  updateCarriere(grade, echelon, quotite, tauxIr) {
    const dateStr = this._fv("date_entree_echelon")
    const c = this._calcCarriere(grade, echelon, quotite, tauxIr, dateStr)
    if (!c) return

    if (this.hasCarriereEchelonActuelTarget) this.carriereEchelonActuelTarget.textContent = `Éch. ${c.echelonActuel}`
    if (this.hasCarriereTibActuelSubTarget)
      this.carriereTibActuelSubTarget.textContent = `IM ${c.imActuel} · ${this.fmt(c.tibActuel.toFixed(2))} €/mois`

    const terminal = !c.echelonSuivant
    if (this.hasCarriereBlockSuivantTarget) this.carriereBlockSuivantTarget.classList.toggle("hidden", terminal)
    if (this.hasCarriereBlockTerminalTarget) this.carriereBlockTerminalTarget.classList.toggle("hidden", !terminal)
    if (this.hasCarriereBlockDateTarget) this.carriereBlockDateTarget.classList.toggle("hidden", terminal)
    if (this.hasCarriereNoDateHintTarget)
      this.carriereNoDateHintTarget.style.display = (!terminal && !dateStr) ? "" : "none"

    if (terminal) return

    if (this.hasCarriereEchelonSuivantTarget) this.carriereEchelonSuivantTarget.textContent = `Éch. ${c.echelonSuivant}`
    if (this.hasCarriereDeltaTibSubTarget)
      this.carriereDeltaTibSubTarget.textContent = `IM ${c.imSuivant} · +${this.fmt(c.deltaTib.toFixed(2))} €/mois`

    if (c.moisRestants == null) {
      if (this.hasCarriereDateEstimeeTarget) this.carriereDateEstimeeTarget.textContent = "—"
      if (this.hasCarriereMoisRestantsSubTarget) this.carriereMoisRestantsSubTarget.textContent = ""
      return
    }

    const fmtMois = new Intl.DateTimeFormat("fr-FR", { month: "short", year: "numeric" })
    if (this.hasCarriereDateEstimeeTarget) this.carriereDateEstimeeTarget.textContent = fmtMois.format(c.dateEstimee)
    if (this.hasCarriereMoisRestantsSubTarget) {
      this.carriereMoisRestantsSubTarget.textContent = c.moisRestants === 0
        ? "Avancement possible maintenant"
        : `Dans ${c.moisRestants} mois`
    }
  }

  _calcCarriere(grade, echelon, quotite, tauxIr, dateEntreeEchelonStr) {
    const im = this.GRILLE[grade]?.[echelon]
    if (!im) return null

    const tibActuel = im * this.VALEUR_POINT * quotite
    const durees = this.DUREES[grade] || this.DUREES.grade1
    const dureeMois = durees[echelon]
    const echelonSuivant = echelon + 1
    const imSuivant = this.GRILLE[grade]?.[echelonSuivant]

    if (dureeMois == null || !imSuivant) {
      return { echelonActuel: echelon, imActuel: im, tibActuel, echelonSuivant: null }
    }

    const tibSuivant = imSuivant * this.VALEUR_POINT * quotite

    let moisRestants = null, dateEstimee = null
    const d = this._parseDateInput(dateEntreeEchelonStr)
    if (d) {
      const today = new Date()
      const moisEcoules = (today.getFullYear() - d.getFullYear()) * 12 + (today.getMonth() - d.getMonth())
      moisRestants = Math.max(dureeMois - moisEcoules, 0)
      dateEstimee = new Date(today.getFullYear(), today.getMonth() + moisRestants, today.getDate())
    }

    return {
      echelonActuel: echelon, imActuel: im, tibActuel,
      echelonSuivant, imSuivant, tibSuivant, deltaTib: tibSuivant - tibActuel,
      moisRestants, dateEstimee
    }
  }

  // ── Validation par étape ──────────────────────────────────────
  _validateCurrentStep() {
    const panel = this.panelTargets.find(p => parseInt(p.dataset.step) === this.currentStepValue)
    if (!panel) return true
    const invalid = Array.from(panel.querySelectorAll("[required]")).filter(f =>
      !f.closest(".hidden") && (f.type === "checkbox" ? !f.checked : !f.value || f.value.trim() === "")
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

  // Pour un groupe de boutons radio (plusieurs éléments partagent le name), renvoie la valeur
  // de celui qui est coché plutôt que le premier du DOM.
  _fv(name) {
    const els = this.formTarget.querySelectorAll(`[name='simulation_session[${name}]']`)
    if (els.length <= 1) return els[0]?.value
    const checked = Array.from(els).find(el => el.checked)
    return (checked || els[0]).value
  }

  // Écrit une valeur pré-extraite d'un bulletin dans le champ correspondant du wizard,
  // marque son .field-group comme "pré-rempli" (retiré dès que l'utilisateur touche le
  // champ) et déclenche un événement change pour que les listeners dépendants existants
  // (professionChanged, gradeChanged, updateTib, updateDates…) s'exécutent normalement.
  _setFv(name, value) {
    if (value === undefined || value === null || value === "") return false
    const els = this.formTarget.querySelectorAll(`[name='simulation_session[${name}]']`)
    if (!els.length) return false

    if (els.length > 1) {
      const match = Array.from(els).find(el => el.value == value)
      if (!match) return false
      match.checked = true
    } else if (els[0].tagName === "SELECT") {
      // Les valeurs numériques (ex. quotite 1.0) perdent leur format exact en
      // traversant le JSON ("1.0" -> 1) : comparer les options en float, pas en string.
      const target = parseFloat(value)
      const option = Array.from(els[0].options).find(o => o.value === String(value) || parseFloat(o.value) === target)
      if (!option) return false
      els[0].value = option.value
    } else {
      els[0].value = value
    }

    // Déclenché AVANT le marquage "pré-rempli" : ce change synthétique sert à réveiller les
    // listeners dépendants existants (professionChanged, gradeChanged...), pas à signaler une
    // édition utilisateur — sinon le listener de nettoyage ci-dessous s'auto-déclencherait.
    els[0].dispatchEvent(new Event("change", { bubbles: true }))

    const group = els[0].closest(".field-group")
    if (group) {
      group.classList.add("field-prefilled")
      const clear = () => group.classList.remove("field-prefilled")
      els[0].addEventListener("input", clear, { once: true })
      els[0].addEventListener("change", clear, { once: true })
    }

    return true
  }

  // ── Upload bulletin (pré-remplissage + comparaison auto) ────────
  async uploadBulletin(e) {
    const file = e.target.files[0]
    if (!file) return

    this._showExtractBanner("Analyse du bulletin en cours…", "info")

    const fd = new FormData()
    fd.append("bulletin", file)
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const res = await fetch("/simulations/extract_bulletin", {
        method: "POST",
        headers: { "X-CSRF-Token": csrf, "Accept": "application/json" },
        body: fd
      })
      const data = await res.json()

      if (!res.ok || (data.errors && data.errors.length)) {
        this._showExtractBanner("Extraction impossible — vous pouvez continuer la saisie manuellement.", "warn")
        return
      }

      this._applyExtraction(data)
    } catch (err) {
      this._showExtractBanner("Extraction impossible — vous pouvez continuer la saisie manuellement.", "warn")
    }
  }

  _applyExtraction(data) {
    const header = data.header || {}
    let filled = 0

    // La profession doit être posée en premier : son `change` reconstruit les options
    // du select grade (professionChanged → _initGradeOptions) — le grade posé avant
    // serait sinon écrasé par ce rebuild.
    if (this._setFv("profession", header.profession)) filled++
    if (this._setFv("grade", header.grade)) filled++
    if (this._setFv("statut", header.statut)) filled++
    if (this._setFv("echelon", header.echelon)) filled++
    if (this._setFv("quotite", header.quotite)) filled++
    if (this._setFv("mois_paie", header.mois_paie)) filled++

    this.realLineFieldTargets.forEach(input => {
      const value = data.real_lines?.[input.dataset.code]
      if (value !== undefined && value !== null && value !== "") input.value = value
    })
    if (this.hasRealBrutFieldTarget && data.real_totals?.brut != null) {
      this.realBrutFieldTarget.value = data.real_totals.brut
    }
    if (this.hasRealNetFieldTarget && data.real_totals?.net != null) {
      this.realNetFieldTarget.value = data.real_totals.net
    }

    const confidenceLabel = { high: "élevée", medium: "moyenne", low: "faible", none: "aucune" }[data.confidence] || data.confidence
    const level = data.confidence === "high" ? "ok" : data.confidence === "none" ? "warn" : "info"
    let message = filled > 0
      ? `Bulletin analysé (confiance : ${confidenceLabel}) — ${filled} champ(s) pré-rempli(s), à vérifier.`
      : `Bulletin analysé (confiance : ${confidenceLabel}) — aucun champ de situation reconnu, saisie manuelle nécessaire.`
    if (data.warnings?.length) message += " " + data.warnings.join(" ")
    this._showExtractBanner(message, level)

    this.updateSidebar()
    this.updateProgress()
  }

  _showExtractBanner(message, level) {
    if (!this.hasExtractBannerTarget) return
    this.extractBannerTarget.textContent = message
    this.extractBannerTarget.className = `alert alert--${level}`
  }

  _fv_tib() {
    const grade   = this._fv("grade")   || "grade1"
    const echelon = parseInt(this._fv("echelon")) || 1
    const quotite = parseFloat(this._fv("quotite")) || 1.0
    const im      = this.GRILLE[grade]?.[echelon] || 0
    return im * this.VALEUR_POINT * quotite
  }

  _tarifSelf(im) {
    const ligne = this.SELF_TARIFS.find(l => l.max === null || im <= l.max)
    return ligne ? ligne.tarif : this.SELF_TARIFS[this.SELF_TARIFS.length - 1].tarif
  }

  _calcSft(nb, tib, alternee) {
    let sft = 0
    if (nb === 1)      sft = 2.29
    else if (nb === 2) sft = Math.max(73.04, 10.67 + tib * 0.03)
    else if (nb >= 3)  sft = Math.max(181.56 + (nb-3)*129.10, 15.24 + tib*0.08 + (nb-3)*(4.57 + tib*0.06))
    return alternee && sft > 0 ? sft / 2 : sft
  }

  // Contingent de 20h dédié aux heures sup de NUIT uniquement (IT7 jusqu'à 20h, DHN
  // au-delà, même taux que IT7). Dimanche/férié/jour sont payés directement, hors
  // contingent, à leur propre taux. Miroir de HeuresSupM2Calculator (fiche corrective
  // codeur IT7/DHN du 17/08/2026).
  _calcHeuresSupM2(baseH, hNuit, hDimanche, hFerie, hJour) {
    const tauxNuit  = this._tronquerTaux(baseH * 2.52)
    const tauxDimJf = this._tronquerTaux(baseH * 2.10)
    const tauxJour  = this._tronquerTaux(baseH * 1.26)

    const it7h = Math.min(hNuit, 20)
    const dhnh = Math.max(hNuit - 20, 0)
    const nuit = (tauxNuit * it7h) + (tauxNuit * dhnh)
    const autres = (tauxDimJf * (hDimanche + hFerie)) + (tauxJour * hJour)

    return { nuit, autres }
  }

  // Règle moteur AP-HP : taux horaire tronqué au multiple inférieur de 0,02 € (pas arrondi)
  _tronquerTaux(taux) {
    return Math.floor(taux / 0.02) * 0.02
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
