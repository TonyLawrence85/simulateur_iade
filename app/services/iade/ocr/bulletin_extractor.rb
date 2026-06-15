# frozen_string_literal: true

module Iade
  module Ocr
    class BulletinExtractor
      Result = Struct.new(
        :lines, :totals, :strategy, :confidence,
        :raw_text, :errors, :warnings,
        keyword_init: true
      )

      KNOWN_CODES = {
        "BT0" => { label: "TR. MENS. REEL",       type: :brut },
        "CW1" => { label: "COMPL. TRAITEMENT",    type: :brut },
        "LP1" => { label: "PRIME INFIRMIERE", type: :brut },
        "LPN" => { label: "PRIME SP INF ANEST",   type: :brut },
        "BR0" => { label: "IND. DE RESIDENCE",    type: :brut },
        "KB1" => { label: "BONIFICATION IND",     type: :brut },
        "KR0" => { label: "IND. RESID. N.B.I",    type: :brut },
        "IS1" => { label: "IND. SPEC.SUJETION",   type: :brut },
        "KS1" => { label: "IND. SP. SUJ. NBI",    type: :brut },
        "KS0" => { label: "S.F.T. N.B.I",         type: :brut },
        "CS0" => { label: "S.F.T. PERCU",         type: :brut },
        "DTC" => { label: "IND COMP CSG",         type: :brut },
        "WT1" => { label: "REMBOUR. TRANSPORT",   type: :brut },
        "JMA" => { label: "IND. NUIT MAJOREE",    type: :brut },
        "TP7" => { label: "TP7",                  type: :brut },
        "IT7" => { label: "IT7",                  type: :brut },
        "DHN" => { label: "DHN",                  type: :brut },
        "RAF" => { label: "RETRAITE ADD",         type: :deduction },
        "RCN" => { label: "CNRACL RETRAITE",      type: :deduction },
        "RCB" => { label: "CNRACL.*N.B.I",        type: :deduction },
        "UCB" => { label: "C.S.G. ET R.D.S",      type: :deduction },
        "UCX" => { label: "CSG MALADIE",          type: :deduction },
        "UC8" => { label: "CSG SUR TTA",          type: :deduction },
        "VR7" => { label: "REDUC COTIS",          type: :deduction },
        "Q60" => { label: "MT PAS TAUX PERS",     type: :deduction }
      }.freeze

      def self.call(file_path:)
        new(file_path: file_path).call
      end

      def initialize(file_path:)
        @file_path = file_path.to_s
        @errors    = []
        @warnings  = []
      end

      def call
        validate_file!
        return failure_result if @errors.any?

        strategy, raw_text = extract_text

        if raw_text.blank?
          @errors << "Impossible d'extraire le texte du bulletin"
          return failure_result
        end

        lines      = Iade::Ocr::LineParser.parse(raw_text, known_codes: KNOWN_CODES)
        totals     = Iade::Ocr::TotalsParser.parse(raw_text)
        confidence = assess_confidence(lines, totals)

        Result.new(
          lines: lines, totals: totals, strategy: strategy,
          confidence: confidence, raw_text: raw_text,
          errors: @errors, warnings: @warnings
        )
      end

      private

      def extract_text
        extension = File.extname(@file_path).downcase
        case extension
        when ".pdf"
          try_pdf_text_extraction || try_tesseract_on_pdf
        when ".jpg", ".jpeg", ".png", ".heic", ".webp"
          try_tesseract_on_image
        else
          @errors << "Format non supporté : #{extension}"
          nil
        end
      end

      def try_pdf_text_extraction
        extractor = Iade::Ocr::PdfTextExtractor.new(@file_path)
        text = extractor.extract
        return nil if text.blank? || text.strip.length < 50

        [:pdf_text, text]
      rescue StandardError => e
        @warnings << "Extraction PDF natif échouée : #{e.message}"
        nil
      end

      def try_tesseract_on_pdf
        extractor = Iade::Ocr::TesseractExtractor.new(@file_path, source: :pdf)
        text = extractor.extract
        return nil if text.blank?

        @warnings << "Bulletin scanné — extraction OCR appliquée"
        [:tesseract, text]
      rescue StandardError => e
        @errors << "OCR échoué : #{e.message}"
        nil
      end

      def try_tesseract_on_image
        extractor = Iade::Ocr::TesseractExtractor.new(@file_path, source: :image)
        text = extractor.extract
        return nil if text.blank?

        [:tesseract, text]
      rescue StandardError => e
        @errors << "OCR image échoué : #{e.message}"
        nil
      end

      def validate_file!
        unless File.exist?(@file_path)
          @errors << "Fichier introuvable : #{@file_path}"
          return
        end
        return unless File.size(@file_path) > 20 * 1_048_576

        @errors << "Fichier trop volumineux (max 20 Mo)"
      end

      def assess_confidence(lines, totals)
        critical = %w[BT0 CW1 RCN Q60]
        found = critical.count { |c| lines.key?(c) }
        if found == critical.size && totals[:brut].present?
          :high
        elsif found >= 2
          :medium
        else
          :low
        end
      end

      def failure_result
        Result.new(
          lines: {}, totals: {}, strategy: :none,
          confidence: :none, raw_text: nil,
          errors: @errors, warnings: @warnings
        )
      end
    end
  end
end
