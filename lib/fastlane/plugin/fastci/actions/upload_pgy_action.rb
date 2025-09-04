require 'fastlane/action'
require 'fastlane/plugin/pgyer'
include Fastlane::Helper

module Fastlane
  module Actions
    # 上传蒲公英
    class UploadPgyAction < Action
      def self.run(params)
        UI.message("*************| 开始上传蒲公英 |*************")

        unless CommonHelper.is_validate_string(Environment.pgy_api_key)
          UI.message("*************| 没有配置 pgy_api_key |*************")
          return
        end

        ipa_path = params[:ipa_path] || ""

        pgyinfo = PgyerAction.run(
          ipa: ipa_path,
          api_key: Environment.pgy_api_key,
          password: Environment.pgy_password,
          install_type: "2"
        )

        return pgyinfo
      end

      def self.description
        "上传蒲公英"
      end

      def self.available_options
        []
      end

      def self.is_supported?(platform)
        platform == :ios
      end

      def self.category
        :building
      end

    end
  end
end