# frozen_string_literal: true

module Iade
  module Ocr
    class BulletinExtractor
      Result = Struct.new(
        :lines, :totals, :header, :strategy, :confidence,
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
        "XRN" => { label: "RET. RESTAU. NUIT",    type: :deduction },
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
        "Q60" => { label: "MT PAS TAUX PERS",     type: :deduction },
        # Primes/brut produits par PayslipCalculator, absents jusqu'ici de ce dictionnaire.
        "IBA" => { label: "ABAT.PPCR.CAT A",       type: :deduction },
        "FMD" => { label: "FORFAIT MOBILITES DUR", type: :brut },
        "JW0" => { label: "IND. DIM. & JOURS FERIES", type: :brut },
        "GAR" => { label: "GARDES WEEKEND",        type: :brut },
        "PSR" => { label: "PRIME DE SERVICE",      type: :brut },
        "LSU" => { label: "INDEM. EXCEP",          type: :brut },
        "DIV" => { label: "PRIMES DIVERSES",       type: :brut },
        "FT1" => { label: "IND. TUTORAT STAGIAIRE", type: :brut },
        "FT9" => { label: "PRIME TUTORAT SOIGNANT", type: :brut },
        "RET" => { label: "RETRAITE IRCANTEC",     type: :deduction },
        # Retenues absence (Iade::AbsencesCalculator::CODES).
        "07C" => { label: "RET. TR. BRUT 10%",        type: :deduction },
        "30A" => { label: "RET. TR. BRUT CAR",         type: :deduction },
        "30B" => { label: "RET. I.A./I.R. CAR",        type: :deduction },
        "07A" => { label: "RET. N.B.I. 10%",           type: :deduction },
        "30G" => { label: "RET. N.B.I. CAR",           type: :deduction },
        "30F" => { label: "RET. NBI IR/IA CAR",        type: :deduction },
        "07L" => { label: "RET. IND. SP. 10%",         type: :deduction },
        "07E" => { label: "RET. IND. SUJ. 10%",        type: :deduction },
        "30K" => { label: "RET. IND.SP.NBI CAR",       type: :deduction },
        "50C" => { label: "RET. TR. BRUT 50%",         type: :deduction },
        "50L" => { label: "RET. IND. SP. 50%",         type: :deduction },
        "DTR" => { label: "RET. IND. COMP",            type: :deduction },
        "CL5" => { label: "RET. TR. BRUT 50%.*CLM",    type: :deduction },
        "CL5I" => { label: "RET. I.A./I.R. 50%.*CLM",  type: :deduction },
        "CLR" => { label: "RET. PRIMES.*CLM",          type: :deduction },
        "CLRN" => { label: "RET. N.B.I..*CLM",         type: :deduction },
        "ANR" => { label: "ABSENCE NON REMUNEREE",     type: :deduction }
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
        header     = Iade::Ocr::HeaderParser.parse(raw_text)
        confidence = assess_confidence(lines, totals)

        Result.new(
          lines: lines, totals: totals, header: header, strategy: strategy,
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
          lines: {}, totals: {}, header: {}, strategy: :none,
          confidence: :none, raw_text: nil,
          errors: @errors, warnings: @warnings
        )
      end
    end
  end
end
