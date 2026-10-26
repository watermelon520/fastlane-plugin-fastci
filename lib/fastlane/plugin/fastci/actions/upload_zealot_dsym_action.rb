require 'fastlane/plugin/fastci/helper/fastci_zealot_helper'

module Fastlane
  module Actions
    # 固定走官方 iOS dSYM 流程，不暴露 Android 或 macOS 参数。
    class UploadZealotDsymAction < ZealotDebugFileAction
      extend Fastlane::Helper::FastciZealotHelper

      def self.run(params)
        values = zealot_parameters(params)
        validate_zealot_connection!(values)
        values[:platform] = 'ios'
        values[:zip_file] ||= Actions.lane_context[SharedValues::DSYM_OUTPUT_PATH] unless values[:path]
        values[:path] ||= Actions.lane_context[SharedValues::XCODEBUILD_ARCHIVE] unless values[:zip_file]

        unless values[:zip_file] || values[:path]
          UI.user_error!('请指定 dSYM zip_file、xcarchive path，或先执行 gym/package')
        end

        if values[:zip_file] && !File.file?(values[:zip_file])
          UI.user_error!("dSYM 压缩文件不存在：#{values[:zip_file]}")
        end
        if values[:path] && !File.directory?(values[:path])
          UI.user_error!("Xcode archive 不存在：#{values[:path]}")
        end

        Actions.lane_context.delete(SharedValues::ZEAALOT_ERROR_MESSAGE)
        super(FastlaneCore::Configuration.create(ZealotDebugFileAction.available_options, values))
      end

      # 上游只检查响应中的 error 字段；非成功 HTTP 状态不能计为上传成功。
      def self.parse_response(response, upload_url, fail_on_error)
        return unless response

        unless response.success? && response.body.is_a?(Hash)
          return show_error("Zealot dSYM 上传失败（HTTP #{response.status}）", fail_on_error)
        end

        super
      end
      private_class_method :parse_response

      def self.available_options
        zealot_options(
          ZealotDebugFileAction,
          excluding: [:platform, :android_build_type, :android_flavor]
        )
      end

      def self.description
        '上传 iOS dSYM 到 Zealot，支持 zip_file、xcarchive 或本次 gym 产物'
      end

      def self.example_code
        ['upload_zealot_dsym(zip_file: "./App.app.dSYM.zip")']
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
