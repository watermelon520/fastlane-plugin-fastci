require 'fastlane/action'
include Fastlane::Helper

module Fastlane
  module Actions
    # 重复代码检查
    class DetectDuplicityCodeAction < Action
      def self.run(params)
        UI.message("*************| 开始重复代码检查 |*************")

        # 检查是否安装了 PMD
        unless system("which pmd > /dev/null")
          sh("brew install pmd")
        end

        is_all = params[:is_all] || true
        # 项目路径
        project_path = Dir.pwd

        if is_all
          detect_path = "#{project_path}"
          pmd_command = "--dir #{detect_path}"
        else
          commit_hash = params[:commit_hash] || CommonHelper.read_cached_txt(COMMIT_HASH_FILE)
          swift_files = CommonHelper.get_git_modified_swift_files(commit_hash)

          if swift_files.empty?
            UI.message("*************|❗没有 Swift 变更文件，跳过重复代码检查❗|*************")
            return
          end

          # 创建文件列表
          file_list_path = Constants.DUPLICITY_CODE_MODIFIED_FILE
          swift_files_absolute = swift_files.map { |file| File.expand_path(file, project_path) }
          File.open(file_list_path, "w") { |file| file.puts(swift_files_absolute) }

          pmd_command = "--file-list #{file_list_path}"
        end

        # 忽略文件夹
        ignore_paths = [
          "#{project_path}/Pods/**"
        ]
        exclude_options = ignore_paths.map { |path| "--exclude #{path}" }.join(" ")

        sh("
          pmd cpd \
          --minimum-tokens 100 \
          #{pmd_command} \
          --language swift \
          --format xml \
          #{exclude_options} \
          --ignore-annotations \
          --ignore-identifiers \
          --ignore-literals \
          --no-fail-on-error \
          --no-fail-on-violation \
          > #{Constants.DUPLICITY_CODE_FILE}
        ")

        # 输出无用代码检查报告
        UI.message("*************| 开始输出重复代码检查报告 |*************")

        CommonHelper.generate_and_open_html(
          "Duplicity Code Report",
          "generate_duplicity_code_html.py",
          Constants.DUPLICITY_CODE_FILE,
          Constants.DUPLICITY_CODE_HTML_FILE
        )
      end

      def self.description
        "重复代码检测"
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
