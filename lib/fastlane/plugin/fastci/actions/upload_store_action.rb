require 'fastlane/action'
include Fastlane::Helper

module Fastlane
  module Actions
    # 上传 AppStore
    class UploadStoreAction < Action
      def self.run(params)

        release_notes = JSON.parse(params[:release_notes] || "") rescue nil

        other_action.app_store_connect_api_key(
          key_id: Environment.connect_key_id,
          issuer_id: Environment.connect_issuer_id,
          key_filepath: File.expand_path("#{Environment.package_file_folder_name}/AuthKey_#{Environment.connect_key_id}.p8"),
          duration: 1200, # optional (maximum 1200)
          in_house: false # optional but may be required if using match/sigh
        )

        if params[:isTestFlight]
          UI.message("*************| 开始上传 TestFlight |*************")
          other_action.upload_to_testflight(
            skip_waiting_for_build_processing: true
          )
        else
          UI.message("*************| 开始上传 AppStore |*************")
          
          # 构建上传参数，只有当 release_notes 有效时才添加
          upload_options = {
            skip_metadata: false,
            skip_screenshots: true,
            run_precheck_before_submit: false,
            precheck_include_in_app_purchases: false,
            force: true,
            submit_for_review: false,
            automatic_release: false
          }
          
          # 只有当 release_notes 不为 nil 且不为空时才添加
          if release_notes && !release_notes.empty?
            upload_options[:release_notes] = release_notes
          end
          
          other_action.upload_to_app_store(upload_options)
        end
      end

      def self.description
        "上传 AppStore"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :release_notes,
            description: "更新文案, 格式为 { \"zh-Hans\": \"修复问题\", \"en-US\": \"bugfix\"} JSON 字符串",
            optional: false,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :isTestFlight,
            description: "是否为 TestFlight 打包",
            optional: false,
            type: Boolean
          )
        ]
      end

      def self.is_supported?(platform)
        platform == :ios
      end

    end
  end
end