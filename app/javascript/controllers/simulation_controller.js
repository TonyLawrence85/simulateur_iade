import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "panel", "stepper",
    "moisPaie", "moisM", "moisM1", "moisM2",
    "imDisplay", "tibDisplay", "tauxHoraireDisplay",
    "progressFill", "confidenceLabel",
    "form", "zoneDisplay", "irDisplay", "sftDisplay", "nbiDisplay",
    "gradeSelect", "dtcMontantRow",
    "navigoMensuelRow", "navigoAnnuelRow", "wt1Display",
    "fmdRow", "fmdEstimate",
    "absencesList", "absenceCard", "absenceTemplate", "absencesSummary"
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
    grade1:    { 1:450, 2:478, 3:506, 4:534, 5:563, 6:593, 7:624, 8:656, 9:690, 10:727 },
    grade2:    { 1:558, 2:582, 3:615, 4:648, 5:681, 6:714, 7:743, 8:769 },
    as_grade1: { 1:373, 2:375, 3:377, 4:388, 5:401, 6:414, 7:429, 8:444, 9:461, 10:485, 11:517 },
    as_grade2: { 1:387, 2:399, 3:411, 4:424, 5:442, 6:460, 7:480, 8:499, 9:519, 10:539, 11:560 },
    ide_grade1:{ 1:376, 2:394, 3:413, 4:439, 5:466, 6:496, 7:527, 8:553, 9:578, 10:610 },
    ide_grade2:{ 1:446, 2:463, 3:487, 4:514, 5:543, 6:572, 7:601, 8:626 }
  }

  MAX_ECHELON = { grade1: 10, grade2: 8, as_grade1: 11, as_grade2: 11, ide_grade1: 10, ide_grade2: 8 }

  GRADE_OPTIONS = {
    iade: [["1er grade", "grade1"], ["2ème grade", "grade2"]],
    as:   [["Classe normale", "as_grade1"], ["Classe supérieure", "as_grade2"]],
    ide:  [["Grade normal", "ide_grade1"], ["Classe supérieure", "ide_grade2"]]
  }

  IR_ZONES = { "75":1, "92":1, "93":1, "94":1, "77":2, "78":2, "91":2, "95":2 }
  IR_TAUX  = { 1: 0.03, 2: 0.01, 3: 0.00 }

  // ── Lifecycle ─────────────────────────────────────────────────
  connect() {
    this._render(this.currentStepValue)
    this.updateDates()
    this._initGradeOptions()
    this.updateTib()
    this.updateProgress()
    this.absenceCardTargets.forEach(card => this._syncAbsenceCard(card))
    this.updateAbsences()
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

  navigoTypeToggle(e) {
    const annuel = e.target.value === "annuel"
    if (this.hasNavigoMensuelRowTarget) this.navigoMensuelRowTarget.style.display = annuel ? "none" : ""
    if (this.hasNavigoAnnuelRowTarget)  this.navigoAnnuelRowTarget.style.display  = annuel ? "" : "none"
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

  // Affiche/masque les questions 3/4 (maladie ordinaire) et 5 (imputabilité au service)
  _syncAbsenceCard(card) {
    const typeSelect = card.querySelector(".absence-field--type")
    const family = typeSelect?.selectedOptions[0]?.dataset.family
    const isProlongationType = typeSelect?.value === "prolongation_maladie_ordinaire"
    const isMaladieOrdinaire = family === "maladie_ordinaire"
    const isImputabilite = family === "imputabilite"
    const q3 = card.querySelector(".absence-q3")
    const q4 = card.querySelector(".absence-q4")
    const q5 = card.querySelector(".absence-q5")
    if (q3) q3.style.display = (isMaladieOrdinaire && !isProlongationType) ? "" : "none"
    if (q4) q4.style.display = isMaladieOrdinaire ? "" : "none"
    if (q5) q5.style.display = isImputabilite ? "" : "none"
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
      } else if (family === "maintenu_100") {
        maintenu100 += joursInMonth
        if (resultEl) resultEl.value = `${joursInMonth}j maintenus à 100%`
      } else {
        nonCalcule += joursInMonth
        if (resultEl) resultEl.value = `${joursInMonth}j — calcul non disponible`
      }
    })

    this._absenceTotals = { carence, cmo90, cmo50 }

    if (this.hasAbsencesSummaryTarget) {
      const total = carence + cmo90 + cmo50 + maintenu100 + nonCalcule
      if (total === 0) {
        this.absencesSummaryTarget.textContent = "Aucune absence saisie ce mois-ci."
      } else {
        const parts = [`${total}j au total`]
        if (carence)     parts.push(`${carence}j carence`)
        if (cmo90)       parts.push(`${cmo90}j à 90%`)
        if (cmo50)       parts.push(`${cmo50}j à 50%`)
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
    const hsJour   = parseFloat(this._fv("hs_jour")) || 0
    const hsNuit   = parseFloat(this._fv("hs_nuit")) || 0
    const hsDimJf  = parseFloat(this._fv("hs_dim_jf")) || 0
    const mPsr     = parseFloat(this._fv("montant_psr")) || 0
    const jAbsPsr  = parseInt(this._fv("jours_absence_psr")) || 0
    const mLsu     = parseFloat(this._fv("montant_lsu")) || 0
    const nbGardes    = parseFloat(this._fv("nb_gardes")) || 0
    const hGarde      = parseFloat(this._fv("heures_par_garde")) || 4
    const { carence: joursCarence = 0, cmo90: joursCmo90 = 0, cmo50: joursCmo50 = 0 } = this._absenceTotals || {}
    const typeNavigo   = this._fv("type_navigo") || "mensuel"
    const wt1Base      = typeNavigo === "annuel"
      ? (parseFloat(this._fv("navigo_montant_annuel")) || 0) / 12
      : (parseFloat(this._fv("wt1_montant")) || 0)
    const heureDebut   = this._fv("heure_debut_service") || "07:36"
    const isNuit       = heureDebut.slice(0, 5) >= "19:00"
    const simulateFmd  = this._fv("simulate_fmd") === "1"
    const fmdJours     = parseInt(this._fv("fmd_jours_annee")) || 0
    const moisPaie     = this._fv("mois_paie") || ""
    const moisNum      = parseInt(moisPaie.slice(-2)) || 0

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
    const baseH    = (tib + ir) * 12 / 1820
    const jma      = baseH * 0.25 * hNuit
    const dimjf    = (hDim + hFerie) * 7.50
    const hsTotal  = baseH * (hsJour * 1.26 + hsNuit * 2.52 + hsDimJf * 2.10)
    const tauxHsN  = baseH * 1.26 * 2
    const gardes   = nbGardes * hGarde * tauxHsN

    // ── Primes variables ──
    const pertePsr = jAbsPsr > 0 ? mPsr * jAbsPsr / 140 : 0
    const psr      = Math.max(0, mPsr - pertePsr)
    const lsu      = mLsu

    // ── Transport (WT1) ──
    const totalAbsence = joursCarence + joursCmo90 + joursCmo50
    let wt1 = 0
    if (wt1Base > 0 && totalAbsence <= 60) {
      wt1 = wt1Base * (isNuit ? 1.0 : 0.75)
      if (quotite < 0.5) wt1 /= 2
    }

    // ── FMD (versé oct./nov. seulement) ──
    let fmd = 0
    if (simulateFmd && fmdJours >= 30 && (moisNum === 10 || moisNum === 11)) {
      if (fmdJours < 60)       fmd = 100
      else if (fmdJours < 100) fmd = 200
      else                     fmd = 300
    }

    // ── Absences (retenues approchées — détail exact sur bulletin) ──
    const retCarence = joursCarence > 0 ? (tib + cti) * joursCarence / 30 : 0
    const retCmo90   = joursCmo90   > 0 ? (tib + cti) * 0.10 * joursCmo90 / 30 : 0
    const retCmo50   = joursCmo50   > 0 ? (tib + cti) * 0.50 * joursCmo50 / 30 : 0
    const retAbsTotal = retCarence + retCmo90 + retCmo50

    // ── Brut ──
    const brut = tib + cti + veil + iade - iba + ir + nbi + irNbi + iss + sft +
                 jma + dimjf + hsTotal + gardes + psr + lsu + wt1 + fmd

    // ── Cotisations estimées ──
    let cnracl = 0, rafp = 0
    if (statut !== "contractuel") {
      cnracl = 0.111 * (tib + cti)
      if (nbiPts > 0) cnracl += 0.111 * nbi
      const primesApresIba = Math.max(0, cti + veil + iade - iba + iss + jma + dimjf + psr + lsu)
      const plafondRafp    = tib * 12 * 0.20
      rafp = Math.min(primesApresIba, plafondRafp) * 0.05
    } else {
      cnracl = 0.0401 * (tib + cti + brut)
    }
    const baseCsg  = brut * 0.9825
    const hsGardes = hsTotal + gardes
    const csgTotal = baseCsg * (0.029 + 0.068) + (hsGardes > 0 ? hsGardes * 0.068 : 0)
    const totalAv  = cnracl + rafp + csgTotal
    const netAvPas = brut - totalAv - retAbsTotal
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

    const hasPlanning = jma > 0 || dimjf > 0 || hsTotal > 0 || gardes > 0
    this._sbLineShow("planning", hasPlanning)
    this._sbLineShow("jma",    jma    > 0); if (jma    > 0) this._sbAmt("jma",    jma)
    this._sbLineShow("dimjf",  dimjf  > 0); if (dimjf  > 0) this._sbAmt("dimjf",  dimjf)
    this._sbLineShow("hs",     hsTotal > 0); if (hsTotal > 0) this._sbAmt("hs",   hsTotal)
    this._sbLineShow("gardes", gardes > 0); if (gardes > 0) this._sbAmt("gardes", gardes)

    const hasPrimesVar = psr > 0 || lsu > 0
    this._sbLineShow("primes-var", hasPrimesVar)
    this._sbLineShow("psr", psr > 0); if (psr > 0) this._sbAmt("psr", psr)
    this._sbLineShow("lsu", lsu > 0); if (lsu > 0) this._sbAmt("lsu", lsu)

    this._sbLineShow("wt1", wt1 > 0); if (wt1 > 0) this._sbAmt("wt1", wt1)
    this._sbLineShow("fmd", fmd > 0); if (fmd > 0) this._sbAmt("fmd", fmd)

    if (this.hasWt1DisplayTarget) {
      this.wt1DisplayTarget.value = wt1 > 0
        ? `${this.fmt(wt1.toFixed(2))} € (${isNuit ? "100% nuit" : "75% jour"}${quotite < 0.5 ? " ÷2" : ""})`
        : totalAbsence > 60 ? "0 € (>60j absence)" : "—"
    }

    const hasAbsences = retAbsTotal > 0
    this._sbLineShow("absences", hasAbsences)
    this._sbLineShow("carence", retCarence > 0); if (retCarence > 0) this._sbNeg("carence", retCarence, true)
    this._sbLineShow("cmo90",   retCmo90   > 0); if (retCmo90   > 0) this._sbNeg("cmo90",   retCmo90,   true)
    this._sbLineShow("cmo50",   retCmo50   > 0); if (retCmo50   > 0) this._sbNeg("cmo50",   retCmo50,   true)

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
