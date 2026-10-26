require 'fastlane/plugin/fastci/helper/fastci_zealot_helper'

module Fastlane
  module Actions
    # iOS IPA 上传：沿用官方传输与结果解析，避免复制 Zealot HTTP 协议。
    class UploadZealotAction < ZealotAction
      extend Fastlane::Helper::FastciZealotHelper

      def self.run(params)
        validate_zealot_connection!(zealot_parameters(params))
        UI.user_error!('请指定 IPA 文件或先执行 gym/package') if params[:file].to_s.empty?

        # 同一 lane 可多次上传，失败时不能返回上一次上传的地址。
        output.each { |key, _description| Actions.lane_context.delete(key.to_sym) }
        super(params)
        return nil unless Actions.lane_context[SharedValues::ZEALOT_RELEASE_ID]

        {
          app_id: Actions.lane_context[SharedValues::ZEALOT_APP_ID],
          release_id: Actions.lane_context[SharedValues::ZEALOT_RELEASE_ID],
          release_url: Actions.lane_context[SharedValues::ZEALOT_RELEASE_URL],
          install_url: Actions.lane_context[SharedValues::ZEALOT_INSTALL_URL],
          qrcode_url: Actions.lane_context[SharedValues::ZEALOT_QRCODE_URL]
        }
      end

      def self.available_options
        options = zealot_options(ZealotAction, excluding: [:file])
        options << FastlaneCore::ConfigItem.new(
          key: :file,
          env_name: 'ZEALOT_FILE',
          description: 'iOS IPA 路径，默认使用本次 gym 的产物',
          optional: true,
          default_value: Actions.lane_context[SharedValues::IPA_OUTPUT_PATH],
          type: String,
          verify_block: proc do |value|
            unless File.file?(value) && File.extname(value).casecmp('.ipa').zero?
              UI.user_error!("不是有效的 IPA 文件：#{value}")
            end
          end
        )
        options
      end

      def self.description
        '上传 iOS IPA 到 Zealot，返回应用、版本和下载地址'
      end

      def self.example_code
        ['upload_zealot(file: "./App.ipa", changelog: "iOS 更新说明")']
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
