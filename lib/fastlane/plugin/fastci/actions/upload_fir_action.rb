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
        )
        UI.message("*************| firinfo = #{firinfo} |*************")

        short = firinfo[:short]
        download_domain = firinfo[:download_domain]
        release_id = firinfo[:release_id]

        download_url = FirHelper.build_download_url(download_domain, short)
        firinfo[:download_url] = download_url
        firinfo[:qrcode_path] = FirHelper.build_qrcode(download_url)

        return firinfo
      end

      def self.description
        "上传Fir"
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