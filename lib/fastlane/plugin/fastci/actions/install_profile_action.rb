require 'fastlane/action'
include Fastlane::Helper

module Fastlane
  module Actions
    # 安装 provisioningProfile
    class InstallProfileAction < Action
      def self.run(params)
        UI.message("*************| 开始安装 provisioningProfile |*************")
        
        provisioning_profile_paths = Dir.glob(File.expand_path("#{Environment.package_file_folder_name}/*.mobileprovision"))
        provisioning_profile_paths.each do |path|
          other_action.install_provisioning_profile(
            path: path
          )
        end
      end

      def self.description
        "安装 provisioningProfile"
      end

      def self.available_options
        []
      end

      def self.is_supported?(platform)
        platform == :ios
      end

      def self.category
        :code_signing
      end

    end
  end
end