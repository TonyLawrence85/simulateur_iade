# frozen_string_literal: true

module Iade
  module Ocr
    # Extrait les champs d'en-tête (situation) d'un bulletin AP-HP, en complément de
    # TotalsParser (totaux) et LineParser (lignes de paie). Chaque champ retourne nil si
    # non trouvé — jamais de valeur devinée à tort, la clé est alors absente du hash final
    # (voir #parse, `.compact`) et le champ correspondant du wizard reste à saisir manuellement.
    class HeaderParser
      MOIS_FR = {
        "janvier" => "01", "février" => "02", "fevrier" => "02", "mars" => "03",
        "avril" => "04", "mai" => "05", "juin" => "06", "juillet" => "07",
        "août" => "08", "aout" => "08", "septembre" => "09", "octobre" => "10",
        "novembre" => "11", "décembre" => "12", "decembre" => "12"
      }.freeze

      STATUT_PATTERNS = {
        /TITULAIRE/i => "titulaire",
        /STAGIAIRE/i => "stagiaire",
        /CONTRACTUEL/i => "contractuel"
      }.freeze

      # profession => [[regex sur la ligne "Grade : ...", valeur grade], ...]
      # Entrées IADE vérifiées contre un bulletin AP-HP réel (juillet 2026, IADE grade2
      # échelon 4 : "Grade : INF ANESTH GRADE 2"). Entrées IDE/AS non vérifiées sur bulletin
      # réel — volontairement étroites : mieux vaut ne rien remplir qu'un mauvais grade.
      GRADE_PATTERNS = {
        "iade" => [
          [/INF\s*ANESTH.*GRADE\s*2/i, "grade2"],
          [/INF\s*ANESTH.*GRADE\s*1/i, "grade1"]
        ],
        "ide" => [
          [/INFIRMIER(?!\s*ANESTH).*CLASSE\s*SUP/i, "ide_grade2"],
          [/INFIRMIER(?!\s*ANESTH).*GRADE\s*1/i, "ide_grade1"]
        ],
        "as" => [
          [/AIDE.?SOIGNANT.*CLASSE\s*SUP/i, "as_grade2"],
          [/AIDE.?SOIGNANT.*CLASSE\s*NORMALE/i, "as_grade1"]
        ]
      }.freeze

      def self.parse(raw_text)
        new(raw_text).parse
      end

      def initialize(raw_text)
        @lines = raw_text.to_s.lines.map(&:strip).reject(&:blank?)
      end

      def parse
        {
          mois_paie: extract_mois_paie,
          statut: extract_statut,
          echelon: extract_echelon,
          quotite: extract_quotite,
          **extract_profession_grade
        }.compact
      end

      private

      def extract_mois_paie
        line = @lines.find { |l| l.match?(/\bMois\b/i) }
        return nil unless line

        m = line.match(/(#{MOIS_FR.keys.join('|')})\s+(\d{4})/i)
        return nil unless m

        "#{m[2]}-#{MOIS_FR[m[1].downcase]}"
      end

      def extract_statut
        line = @lines.find { |l| l.match?(/Qualit.*statutaire/i) }
        return nil unless line

        STATUT_PATTERNS.each { |pattern, value| return value if line.match?(pattern) }
        nil
      end

      def extract_echelon
        line = @lines.find { |l| l.match?(/^Echelon\s*:/i) }
        return nil unless line

        m = line.match(/Echelon\s*:\s*0*(\d+)/i)
        m && m[1].to_i
      end

      def extract_quotite
        line = @lines.find { |l| l.match?(/Temps\s+de\s+travail/i) }
        return nil unless line

        m = line.match(/(\d{1,3})\s*%/)
        m && (m[1].to_f / 100.0)
      end

      def extract_profession_grade
        line = @lines.find { |l| l.match?(/^Grade\s*:/i) }
        return {} unless line

        GRADE_PATTERNS.each do |profession, patterns|
          patterns.each do |pattern, grade|
            return { profession: profession, grade: grade } if line.match?(pattern)
          end
        end
        {}
      end
    end
  end
end
