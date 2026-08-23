module ApplicationHelper
  GRADE_LABELS = {
    "grade1" => "IADE 1er grade", "grade2" => "IADE 2e grade",
    "ide_grade1" => "IDE grade 1", "ide_grade2" => "IDE grade 2",
    "as_grade1" => "AS classe normale", "as_grade2" => "AS classe supérieure"
  }.freeze

  PROFESSION_LABELS = {
    "iade" => "IADE — Infirmier Anesthésiste",
    "ide" => "IDE — Infirmier Diplômé d'État",
    "as" => "AS — Aide-Soignant(e)"
  }.freeze

  def grade_label(code)
    GRADE_LABELS[code] || code
  end

  def profession_label(code)
    PROFESSION_LABELS[code] || code
  end
end
