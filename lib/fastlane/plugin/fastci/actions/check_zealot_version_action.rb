require 'fastlane/plugin/fastci/helper/fastci_zealot_helper'

module Fastlane
  module Actions
    # 查询 iOS 应用已上传版本，是否跳过后续打包由调用方决定。
    class CheckZealotVersionAction < ZealotVersionCheckAction
      extend Fastlane::Helper::FastciZealotHelper

      def self.run(params)
        validate_zealot_connection!(zealot_parameters(params))
        [
          SharedValues::ZEALOT_VERSION_EXISTED,
          SharedValues::ZEAALOT_ERROR_MESSAGE,
          SharedValues::ZEALOT_LATEST_RELEASE_ID,
          SharedValues::ZEALOT_LATEST_RELEASE_VERSION,
          SharedValues::ZEALOT_LATEST_VERSION,
          SharedValues::ZEALOT_LATEST_RELEASE_URL,
          SharedValues::ZEALOT_LATEST_INSTALL_URL,
          SharedValues::ZEALOT_LATEST_QRCODE_URL,
          SharedValues::ZEALOT_LATEST_CONTEXT
        ].each { |key| Actions.lane_context.delete(key) }

        response = check_app_version(params)
        # 上游非终止模式在网络错误时返回 false，不能继续读取 response.status。
        return nil unless response

        unless [200, 404].include?(response.status) && response.body.is_a?(Hash)
          show_error("Zealot 版本查询失败（HTTP #{response.status}）", params[:fail_on_error])
          return nil
        end

        parse_response(response, params[:fail_on_error])
      end

      def self.available_options
        zealot_options(ZealotVersionCheckAction)
      end

      def self.description
        '按 Bundle ID 与版本号或 Git commit 查询 Zealot，返回是否已存在'
      end

      def self.example_code
        ['check_zealot_version(bundle_id: "com.example.app", release_version: "1.0", build_version: "1")']
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
