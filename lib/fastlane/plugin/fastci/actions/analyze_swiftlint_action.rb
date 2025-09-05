require 'fastlane/action'
include Fastlane::Helper

module Fastlane
  module Actions
    # 代码分析
    class AnalyzeSwiftlintAction < Action
      def self.run(params)
        UI.message("*************| 开始代码分析 |*************")

        # 检查是否安装了 SwiftLint
        unless system("which swiftlint > /dev/null")
          sh("brew install swiftlint")
        end

        is_all = params[:is_all] || true
        is_from_package = params[:is_from_package] || false
        configuration = params[:configuration] || "Debug"

        # 如果不是从打包流程调用，需要先构建项目
        if is_from_package == false
          UI.message("*************| 构建项目以生成索引存储 |*************")

          other_action.gym(
            clean: true,
            silent: true,
            workspace: Environment.workspace,
            scheme: Environment.scheme,
            configuration: configuration,
            buildlog_path: Constants.BUILD_LOG_DIR,
            skip_archive: true,
            skip_package_ipa: true
          )
        end

        log_dir = File.expand_path(Constants.BUILD_LOG_DIR)
        log_file = sh("ls -t #{log_dir}/*.log | head -n 1").strip

        analyze_file = File.expand_path(Constants.SWIFTLINT_ANALYZE_FILE)

        if is_all
          sh "swiftlint analyze --compiler-log-path #{log_file} > #{analyze_file} || true"
        else
          commit_hash = params[:commit_hash] || read_cached_txt(Constants.COMMIT_HASH_FILE)
          swift_files = CommonHelper.get_git_modified_swift_files(commit_hash)

          if swift_files.empty?
            UI.message("*************|❗没有 Swift 变更文件，跳过代码分析❗|*************")
            return
          end

          files_to_analyze = swift_files.join(" ")
          sh "swiftlint analyze --compiler-log-path #{log_file} #{files_to_analyze} > #{analyze_file} || true"
        end

        # 输出代码分析报告
        UI.message("*************| 开始输出代码分析报告 |*************")

        CommonHelper.generate_and_open_html(
          "Code Analyze Report",
          "generate_lint_html.py",
          Constants.SWIFTLINT_ANALYZE_FILE,
          Constants.SWIFTLINT_ANALYZE_HTML_FILE
        )
      end

      def self.description
        "静态代码分析"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :is_all,
            description: "是否检查所有文件",
            optional: true, 
            default_value: true,
            type: Boolean
          ),
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
            type: String,
            verify_block: proc do |value|
              valid_params = ["Release", "Debug"]
              unless valid_params.include?(value)
                UI.user_error!("无效的编译环境: #{value}。支持的环境: #{valid_params.join(', ')}")
              end
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :commit_hash,
            description: "上一次提交哈希, 会比较该哈希到最新哈希",
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
