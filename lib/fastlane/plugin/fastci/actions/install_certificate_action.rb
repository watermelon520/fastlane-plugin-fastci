require 'fastlane/action'
include Fastlane::Helper

module Fastlane
  module Actions
    # 安装 p12 证书
    class InstallCertificateAction < Action
      def self.run(params)
        UI.message("*************| 开始安装 p12 证书 |*************")

        certificate_paths = Dir.glob("../#{Environment.certificate_folder_name}/*.p12")
        certificate_paths.each do |path|
          import_certificate(
            certificate_path: File.expand_path(path),
            certificate_password: "#{Environment.certificate_password}",
            keychain_name: "login.keychain",
            keychain_password: "#{Environment.keychain_password}"
          )
        end
      end

      def self.description
        "安装 p12 证书"
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