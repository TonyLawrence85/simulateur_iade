# frozen_string_literal: true

module Iade
  module Ocr
    class PdfTextExtractor
      PYTHON_SCRIPT = <<~PYTHON
        import sys, json, pdfplumber

        path = sys.argv[1]
        result = {"text": "", "error": None}

        try:
            with pdfplumber.open(path) as pdf:
                lines = []
                for page in pdf.pages:
                    words = page.extract_words(x_tolerance=3, y_tolerance=3)
                    lines_dict = {}
                    for w in words:
                        y_key = round(w["top"] / 4) * 4
                        if y_key not in lines_dict:
                            lines_dict[y_key] = []
                        lines_dict[y_key].append((w["x0"], w["text"]))

                    for y_pos in sorted(lines_dict.keys()):
                        line_words = sorted(lines_dict[y_pos], key=lambda x: x[0])
                        line_text = "  ".join(w[1] for w in line_words)
                        lines.append(line_text)

                result["text"] = "\\n".join(lines)
        except Exception as e:
            result["error"] = str(e)

        print(json.dumps(result, ensure_ascii=False))
      PYTHON

      def initialize(file_path)
        @file_path = file_path
      end

      def extract # rubocop:disable Metrics/MethodLength
        tmp = Tempfile.new(["pdf_extract", ".py"])
        tmp.write(PYTHON_SCRIPT)
        tmp.close

        begin
          stdout, stderr, status = Open3.capture3("python3", tmp.path, @file_path)
          raise "Python error: #{stderr.strip}" unless status.success?

          data = JSON.parse(stdout)
          raise "pdfplumber error: #{data['error']}" if data["error"].present?

          data["text"]
        ensure
          File.delete(tmp.path) if File.exist?(tmp.path) # rubocop:disable Lint/NonAtomicFileOperation
        end
      end
    end
  end
end
