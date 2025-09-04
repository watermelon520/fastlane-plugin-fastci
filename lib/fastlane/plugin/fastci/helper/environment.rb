module Fastlane
  module Helper
    module Environment
      # 苹果密钥配置
      def self.connect_key_id
        ENV['CONNECT_KEY_ID']
      end
      def self.connect_issuer_id
        ENV['CONNECT_ISSUER_ID']
      end

      # 项目配置
      def self.scheme
        ENV['SCHEME_NAME']
      end
      def self.target
        ENV['TARGET_NAME']
      end
      def self.workspace
        ENV['WORKSPACE']
      end
      def self.bundleID
        ENV['BUNDLE_ID']
      end
      def self.extension_bundle_ids
        ENV['EXTENSION_BUNDLE_IDS']&.split(",") || []
      end
      def self.schemes
        ENV['SCHEMES_NAME']&.split(",") || []
      end

      # 描述文件配置
      def self.provisioningProfile_folder_name
        ENV['PROFILE_FOLDER_NAME']
      end
      def self.provisioningProfiles_development
        ENV['PROFILE_DEVELOPMENT']
      end
      def self.provisioningProfiles_adhoc
        ENV['PROFILE_ADHOC']
      end
      def self.provisioningProfiles_appstore
        ENV['PROFILE_APPSTORE']
      end
      def self.extension_profiles_development
        ENV['EXTENSION_PROFILES_DEVELOPMENT']&.split(",") || []
      end
      def self.extension_profiles_adhoc
        ENV['EXTENSION_PROFILES_ADHOC']&.split(",") || []
      end
      def self.extension_profiles_appstore
        ENV['EXTENSION_PROFILES_APPSTORE']&.split(",") || []
      end

      # p12 证书配置
      def self.certificate_folder_name
        ENV['PROFILE_FOLDER_NAME']
      end
      def self.certificate_development
        ENV['CERTIFICATE_DEVELOPMENT']
      end
      def self.certificate_distribution
        ENV['CERTIFICATE_DISTRIBUTION']
      end
      def self.certificate_password
        ENV['CERTIFICATE_PASSWORD']
      end
      def self.keychain_password
        ENV['KEYCHAIN_PASSWORD']
      end

      # 蒲公英配置
      def self.pgy_api_key
        ENV['PGY_API_KEY']
      end
      def self.pgy_password
        ENV['PGY_PASSWORD']
      end

      # 钉钉配置
      def self.dingdingToken
        ENV['DINGDING_TOKEN']
      end
    end
  end
end