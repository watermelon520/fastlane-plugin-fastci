require 'fastlane/action'
include Fastlane::Helper

module Fastlane
  module Actions
    # 无用图片检查 
    class DetectUnusedImageAction < Action
      def self.run(params)
        UI.message("*************| 开始无用图片检查 |*************")

        # 检查是否安装了 Mint
        unless system("which mint > /dev/null")
          sh("brew install mint")
        end
        
        # 检查是否安装了 FengNiao
        unless system("mint list | grep -q onevcat/FengNiao")
          sh("mint install onevcat/FengNiao")
        end

        # 构建排除参数
        exclude_paths = ["Carthage", "Pods"]
        if params[:exclude] && !params[:exclude].empty?
          exclude_paths += params[:exclude].split(",").map(&:strip)
        end
        exclude_options = exclude_paths.join(" ")

        fengniao_output = sh("
        mint run onevcat/FengNiao fengniao \
        --list-only \
        --exclude #{exclude_options}
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
        [
          FastlaneCore::ConfigItem.new(
            key: :exclude,
            description: "要排除的路径，多个路径用逗号分隔。默认会排除 Carthage 和 Pods 目录",
            optional: true,
            default_value: nil,
            type: String
          )
        ]
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
