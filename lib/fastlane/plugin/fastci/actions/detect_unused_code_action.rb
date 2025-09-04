require 'fastlane/action'
include Fastlane::Helper

module Fastlane
  module Actions
    # 无用代码检查
    class DetectUnusedCodeAction < Action
      def self.run(params)
        UI.message("*************| 开始无用代码检查 |*************")

        # 检查是否安装了 Periphery
        unless system("which periphery > /dev/null")
          sh("brew install periphery")
        end

        is_from_package = params[:is_from_package] || false
        configuration = params[:configuration] || "Debug"

        # 如果不是从打包流程调用，需要先构建项目
        if is_from_package == false
          puts "*************| 构建项目以生成索引存储 |*************"

          options = {
            clean: true,
            silent: true,
            workspace: Environment.workspace,
            scheme: Environment.scheme,
            configuration: configuration,
            buildlog_path: Constants.BUILD_LOG_DIR,
            skip_archive: true,
            skip_package_ipa: true
          }
          config = FastlaneCore::Configuration.create(Gym::Options.available_options, options)
          Gym::Manager.new.work(config)
        end

        log_dir = File.expand_path(Constants.BUILD_LOG_DIR)
        log_file = sh("ls -t #{log_dir}/*.log | head -n 1").strip
        index_store_path = CommonHelper.extract_index_store_path(log_file)

        schemes = Environment.schemes
        if schemes.empty?
          schemes = Environment.scheme
        end

        # 运行 Periphery 扫描
        periphery_output = sh("
        periphery scan \
        --skip-build \
        --project #{Environment.workspace} \
        --schemes #{schemes.map(&:strip).join(" ")} \
        --index-store-path '#{index_store_path}' \
        --format xcode 2>/dev/null || true
        ")

        CommonHelper.write_cached_txt(Constants.UNUSED_CODE_FILE, periphery_output)

        # 输出无用代码检查报告
        UI.message("*************| 开始输出无用代码检查报告 |*************")

        CommonHelper.generate_and_open_html(
          "Unused Code Report",
          "generate_unused_code_html.py",
          Constants.UNUSED_CODE_FILE,
          Constants.UNUSED_CODE_HTML_FILE
        )
      end

      def self.description
        "无用代码检测"
      end

      def self.available_options
        [
            FastlaneCore::ConfigItem.new(
              key: :is_from_package,
              description: "是否从打包流程调用",
              optional: true,
              default_value: false,
              type: Boolean
            ),
            FastlaneCore::ConfigItem.new(
              key: :configuration,
              description: "构建配置",
              optional: true,
              default_value: "Release",
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
