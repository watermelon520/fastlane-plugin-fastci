module Fastlane
  module Helper
    module Constants
      # cache 文件
      def self.BUILD_NUMBER_FILE
        "fastlane_cache/build_cache.txt"
      end
      def self.COMMIT_HASH_FILE
        "fastlane_cache/commit_cache.txt"
      end
      def self.SWIFTLINT_ANALYZE_FILE
        "fastlane_cache/temp/swiftlint_analyze_result.txt"
      end
      def self.SWIFTLINT_ANALYZE_HTML_FILE
        "fastlane_cache/html/analyze_lint_report.html"
      end
      def self.DUPLICITY_CODE_MODIFIED_FILE
        "fastlane_cache/temp/duplicity_code_modified_files.txt"
      end
      def self.DUPLICITY_CODE_FILE
        "fastlane_cache/temp/duplicity_code_result.xml"
      end
      def self.DUPLICITY_CODE_HTML_FILE
        "fastlane_cache/html/duplicity_code_report.html"
      end
      def self.UNUSED_CODE_FILE
        "fastlane_cache/temp/unused_code_result.txt"
      end
      def self.UNUSED_CODE_HTML_FILE
        "fastlane_cache/html/unused_code_report.html"
      end
      def self.UNUSED_IMAGE_FILE
        "fastlane_cache/temp/unused_image_result.txt"
      end
      def self.UNUSED_IMAGE_HTML_FILE
        "fastlane_cache/html/unused_image_report.html"
      end

      # bulid 产物
      def self.BUILD_LOG_DIR
        "fastlane_cache/build_logs"
      end
      def self.IPA_OUTPUT_DIR
        "fastlane_cache/temp"
      end
    end
  end
end