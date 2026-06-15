# frozen_string_literal: true

module Iade
  module Ocr
    class TesseractExtractor
      TESSERACT_CONFIG = "--psm 6 --oem 1 -l fra"

      def initialize(file_path, source: :pdf)
        @file_path = file_path
        @source    = source
      end

      def extract
        image_paths = @source == :pdf ? rasterize_pdf : [@file_path]
        return "" if image_paths.blank?

        texts = image_paths.map { |img| run_tesseract(img) }
        cleanup(image_paths)
        texts.join("\n\n")
      end

      private

      def rasterize_pdf
        output_dir  = Dir.mktmpdir("iade_ocr_")
        output_base = File.join(output_dir, "page")

        _out, err, status = Open3.capture3(
          "pdftoppm", "-jpeg", "-r", "300", @file_path, output_base
        )
        raise "pdftoppm failed: #{err}" unless status.success?

        Dir.glob("#{output_base}*.jpg").sort # rubocop:disable Lint/RedundantDirGlobSort
      end

      def run_tesseract(image_path)
        output_base = image_path.sub(/\.\w+$/, "_ocr")
        _out, err, status = Open3.capture3(
          "tesseract", image_path, output_base, *TESSERACT_CONFIG.split
        )
        raise "Tesseract failed: #{err}" unless status.success?

        output_file = "#{output_base}.txt"
        text = File.read(output_file, encoding: "UTF-8")
        File.delete(output_file)
        text
      end

      def cleanup(paths)
        paths.each do |p|
          File.delete(p) if File.exist?(p) && p.include?("iade_ocr_")
        end
      rescue StandardError => e
        Rails.logger.warn "[OCR] Cleanup error: #{e.message}"
      end
    end
  end
end
