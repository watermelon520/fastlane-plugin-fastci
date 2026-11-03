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

      # 商店认证支持 CI 提供的 API Key JSON 密钥文件。
      def self.app_store_connect_api_key_path
        ENV['APP_STORE_CONNECT_API_KEY_PATH'].to_s.strip
      end

      # 未指定独立 P8 路径时，保留证书目录下 AuthKey_<KEY_ID>.p8 的原有约定。
      def self.app_store_connect_p8_path
        configured_path = ENV['APP_STORE_CONNECT_P8_PATH'].to_s.strip
        return configured_path unless configured_path.empty?

        File.join(package_file_folder_name.to_s, "AuthKey_#{connect_key_id}.p8")
      end

      # 项目配置
      def self.scheme
        ENV['SCHEME_NAME']
      end
      def self.workspace
        ENV['WORKSPACE_NAME']
      end
      def self.project
        ENV['PROJECT_NAME']
      end
      def self.bundleID
        ENV['BUNDLE_ID']
      end
      def self.extension_bundle_ids
        ENV['EXTENSION_BUNDLE_IDS']&.split(",") || []
      end
      def self.extra_schemes
        ENV['EXTRA_SCHEMES_NAME']&.split(",") || []
      end

      # 证书描述文件等放置的文件夹名称
      def self.package_file_folder_name
        ENV['PACKAGE_FILE_FOLDER_NAME']
      end
      # 是否自动更新描述文件
      def self.is_auto_update_provisioning
        ENV['IS_AUTO_UPDATE_PROVISIONING'] == "true"
      end

      # 描述文件配置
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

      # Fir配置
      def self.fir_api_token
        ENV['FIR_API_TOKEN']
      end
      def self.fir_password
        ENV['FIR_PASSWORD']
      end
      def self.fir_switch_qiniu
        ENV['FIR_SWITCH_QINIU'] == "true"
      end

      # Zealot 配置；可选上传渠道，未配置时不影响现有打包流程。
      def self.zealot_endpoint
        ENV['ZEALOT_ENDPOINT']
      end
      def self.zealot_token
        ENV['ZEALOT_TOKEN']
      end
      def self.zealot_channel_key
        ENV['ZEALOT_CHANNEL_KEY']
      end

      # 钉钉配置
      def self.dingdingToken
        ENV['DINGDING_TOKEN']
      end

      # 商店安装入口由项目配置；上传接口本身不提供 TestFlight 邀请或线上商店地址。
      def self.dingding_testflight_url
        ENV['DINGDING_TESTFLIGHT_URL']
      end
      def self.dingding_app_store_url
        ENV['DINGDING_APP_STORE_URL']
      end

      # 默认兼容原有密码展示，配置 false 后不在群通知中附带安装密码。
      def self.dingding_include_install_password
        ENV.fetch('DINGDING_INCLUDE_INSTALL_PASSWORD', 'true').casecmp('true').zero?
      end

      # Sentry 配置
      def self.sentry_auth_token
        ENV['SENTRY_AUTH_TOKEN']
      end
      def self.sentry_org_slug
        ENV['SENTRY_ORG_SLUG']
      end
      def self.sentry_project_slug
        ENV['SENTRY_PROJECT_SLUG']
      end
      def self.sentry_url
        ENV['SENTRY_URL']
      end

    end
  end
end
