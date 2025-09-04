require 'fastlane/action'
include Fastlane::Helper

module Fastlane
  module Actions
    # 上传 AppStore
    class UploadStoreAction < Action
      def self.run(params)
        UI.message("*************| 开始上传 AppStore |*************")

        other_action.app_store_connect_api_key(
          key_id: Environment.connect_key_id,
          issuer_id: Environment.connect_issuer_id,
          key_filepath: File.expand_path("./AuthKey_#{Environment.connect_key_id}.p8"),
          duration: 1200, # optional (maximum 1200)
          in_house: false # optional but may be required if using match/sigh
        )
        other_action.upload_to_app_store(
          skip_metadata: false,
          skip_screenshots: true,
          force: true,
          submit_for_review: false,
          automatic_release: false,
          release_notes: params[:release_notes]
        )
        
      end

      def self.description
        "上传 AppStore"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :release_notes,
            description: "更新文案, 格式为 { "zh-Hans" => "修复问题", "en-US" => "bugfix"} ",
            optional: false,
            type: Hash
          )
        ]
      end

      def self.is_supported?(platform)
        platform == :ios
      end

    end
  end
end