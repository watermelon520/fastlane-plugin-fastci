require 'fastlane/action'
include Fastlane::Helper

module Fastlane
  module Actions
    # 无用图片检查 
    class DetectUnusedImageAction < Action
      def self.run(params)
        UI.message("*************| 开始无用图片检查 |*************")

        # 检查是否安装了 FengNiao
        unless system("which fengniao > /dev/null")
          sh("brew install mint")
          sh("mint install onevcat/fengniao")
        end

        fengniao_output = sh("
        fengniao \
        --list-only \
        --exclude Carthage Pods \ 
        ")

        CommonHelper.write_cached_txt(Constants.UNUSED_IMAGE_FILE, fengniao_output)

        # 输出无用图片检查报告
        UI.message("*************| 开始输出无用图片检查报告 |*************")

        CommonHelper.generate_and_open_html(
          "Unused Image Report",
          "generate_unused_image_html.py",
          Constants.UNUSED_IMAGE_FILE,
          Constants.UNUSED_IMAGE_HTML_FILE
        )
      end

      def self.description
        "无用图片检测"
      end

      def self.available_options
        []
      end

      def self.is_supported?(platform)
        platform == :ios
      end

      def self.category
        :testing
      end

    end
  end
end
