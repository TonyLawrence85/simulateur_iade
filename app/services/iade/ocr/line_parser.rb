# frozen_string_literal: true

module Iade
  module Ocr
    class LineParser
      AMOUNT_REGEX = /(-?\s*\d{1,3}(?:\s\d{3})*(?:,\d{2})|(-?\d+,\d{2})|-?\d+\.\d{2})/
      CODE_REGEX   = /\A([A-Z]{2,3}\d{0,1})\b/

      def self.parse(raw_text, known_codes:, mode: :auto)
        new(raw_text, known_codes: known_codes, mode: mode).parse
      end

      def initialize(raw_text, known_codes:, mode: :auto)
        @raw_text    = raw_text.to_s
        @known_codes = known_codes
        @mode        = mode
      end

      def parse
        result = {}

        @raw_text.each_line do |raw_line|
          line = raw_line.strip
          next if line.blank?

          code, amount = extract_by_code_prefix(line)
          code, amount = extract_by_label(line) if code.nil?

          next if code.nil? || amount.nil?

          normalized = normalize_amount(amount)
          next unless normalized

          normalized = -normalized.abs if @known_codes.dig(code, :type) == :deduction

          result[code] = normalized
        end

        result
      end

      private

      def extract_by_code_prefix(line)
        match = line.match(CODE_REGEX)
        return [nil, nil] unless match

        code = match[1]
        return [nil, nil] unless @known_codes.key?(code)

        amount = extract_last_amount(line)
        [code, amount]
      end

      def extract_by_label(line)
        @known_codes.each do |code, meta|
          pattern = Regexp.new(Regexp.escape(meta[:label]).gsub('\\.', '.?'), Regexp::IGNORECASE)
          next unless line.match?(pattern)

          amount = extract_last_amount(line)
          return [code, amount] if amount
        end
        [nil, nil]
      end

      def extract_last_amount(line)
        matches = line.scan(AMOUNT_REGEX).map(&:first).compact
        matches.last
      end

      def normalize_amount(str)
        return nil if str.blank?

        cleaned = str.to_s.gsub(/\s/, "").gsub(",", ".").gsub(/\.(?=\d{3}\.)/, "")
        Float(cleaned)
      rescue StandardError
        nil
      end
    end
  end
end
