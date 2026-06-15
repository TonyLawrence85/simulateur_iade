# frozen_string_literal: true

module Iade
  module Ocr
    class TotalsParser
      PATTERNS = {
        brut: [
          /REMUNERATION\s+TOTALE\s+BRUTE/i,
          /TOTAL\s+BRUT/i
        ],
        cotisations: [
          /TOTAL\s+COTISATIONS/i,
          /TOTAL\s+RETENUES/i
        ],
        net_avant_pas: [
          /NET\s+A\s+PAYER\s+AVANT\s+IMP/i,
          /NET\s+AVANT\s+PAS/i
        ],
        net_paye: [
          /REMUNERATION\s+NETTE/i,
          /NET\s+A\s+PAYER\b/i,
          /MONTANT\s+NET\s+VERSE/i
        ]
      }.freeze

      AMOUNT_REGEX = /(-?\d[\d\s]*[,.]\d{2})\s*$/

      def self.parse(raw_text)
        new(raw_text).parse
      end

      def initialize(raw_text)
        @lines = raw_text.to_s.lines.map(&:strip).reject(&:blank?)
      end

      def parse
        result = {}
        PATTERNS.each do |key, patterns|
          patterns.each do |pattern|
            found = find_amount(pattern)
            if found
              result[key] = found
              break
            end
          end
        end
        result
      end

      private

      def find_amount(pattern)
        @lines.each do |line|
          next unless line.match?(pattern)

          m = line.match(AMOUNT_REGEX)
          return normalize(m[1]) if m
        end
        nil
      end

      def normalize(str)
        Float(str.to_s.gsub(/\s/, "").gsub(",", "."))
      rescue StandardError
        nil
      end
    end
  end
end
