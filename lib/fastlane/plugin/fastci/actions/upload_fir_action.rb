require 'fastlane/action'
require 'fastlane/plugin/fir_cli'
include Fastlane::Helper

module Fastlane
  module Actions
    # 上传Fir
    class UploadFirAction < Action
      def self.run(params)
        UI.message("*************| 开始上传Fir |*************")

        firinfo = other_action.fir_cli(
          api_token: Environment.fir_api_token,
          password: Environment.fir_password,
          changelog: params[:changelog],
          switch_to_qiniu: Environment.fir_switch_qiniu
        )
        
        return firinfo
      end

      def self.description
        "上传Fir"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :changelog,
            description: "更新日志",
            optional: true,
            type: String
          ),
        ]
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