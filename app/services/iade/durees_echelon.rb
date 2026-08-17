# frozen_string_literal: true

module Iade
  # Durée minimale en mois par échelon avant avancement (Décret n° 2012-1483 IADE,
  # décrets équivalents IDE/AS) — partagé entre CarriereCalculator (prochain échelon
  # unique) et CarriereProjectionCalculator (projection multi-échelons).
  module DureesEchelon
    DUREES_GRADE1 = {
      1 => 12, 2 => 24, 3 => 24, 4 => 24, 5 => 24,
      6 => 24, 7 => 24, 8 => 36, 9 => 48, 10 => nil
    }.freeze

    DUREES_GRADE2 = {
      1 => 12, 2 => 24, 3 => 24, 4 => 24, 5 => 30,
      6 => 36, 7 => 48, 8 => nil
    }.freeze

    DUREES_AS_GRADE1 = {
      1 => 18, 2 => 18, 3 => 24, 4 => 24, 5 => 30,
      6 => 36, 7 => 36, 8 => 36, 9 => 36, 10 => 48, 11 => nil
    }.freeze

    DUREES_AS_GRADE2 = {
      1 => 18, 2 => 24, 3 => 24, 4 => 24, 5 => 24,
      6 => 30, 7 => 36, 8 => 36, 9 => 36, 10 => 48, 11 => nil
    }.freeze

    DUREES_IDE_GRADE1 = {
      1 => 12, 2 => 24, 3 => 24, 4 => 30, 5 => 36,
      6 => 36, 7 => 36, 8 => 48, 9 => 48, 10 => nil
    }.freeze

    DUREES_IDE_GRADE2 = {
      1 => 12, 2 => 24, 3 => 24, 4 => 24, 5 => 36,
      6 => 36, 7 => 48, 8 => nil
    }.freeze

    DUREES_PAR_GRADE = {
      "grade1"     => DUREES_GRADE1,
      "grade2"     => DUREES_GRADE2,
      "as_grade1"  => DUREES_AS_GRADE1,
      "as_grade2"  => DUREES_AS_GRADE2,
      "ide_grade1" => DUREES_IDE_GRADE1,
      "ide_grade2" => DUREES_IDE_GRADE2
    }.freeze

    def self.for_grade(grade)
      DUREES_PAR_GRADE[grade] || DUREES_GRADE1
    end
  end
end
