require 'fastlane/action'
include Fastlane::Helper

module Fastlane
  module Actions
    # 上传 AppStore
    class UploadStoreAction < Action
      def self.run(params)
        UI.message("*************| 开始上传 AppStore |*************")

        
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

    end
  end
end