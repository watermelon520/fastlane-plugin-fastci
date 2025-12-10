require 'fastlane/action'
require 'fastlane/plugin/sentry'
include Fastlane::Helper

module Fastlane
  module Actions
    # Sentry 上传 dSYM 文件
    class SentryUploadDsymAction < Action
      def self.run(params)
        UI.message("*************| Sentry 开始上传 dSYM 文件 |*************")

        other_action.sentry_debug_files_upload(
          auth_token: Environment.sentry_auth_token,
          org_slug: Environment.sentry_org_slug,
          project_slug: Environment.sentry_project_slug,
          url: Environment.sentry_url
        )
        
      end

      def self.description
        "Sentry 上传 dSYM 文件"
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