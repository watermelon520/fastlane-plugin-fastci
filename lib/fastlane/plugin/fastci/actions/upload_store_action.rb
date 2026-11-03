require 'fastlane/action'
require 'json'
require 'fastlane/plugin/fastci/helper/app_store_resources_helper'
include Fastlane::Helper

module Fastlane
  module Actions
    module SharedValues
      FASTCI_STORE_UPLOAD_RESULT = :FASTCI_STORE_UPLOAD_RESULT
    end

    # 上传 AppStore
    class UploadStoreAction < Action
      def self.run(params)
        # 每次上传重新记录阶段；失败时 package 可区分 IPA 上传与后续资源发布。
        result = { stage: '准备商店上传', ipa_uploaded: false, resources_enabled: false }
        Actions.lane_context[SharedValues::FASTCI_STORE_UPLOAD_RESULT] = result
        resource_params, api_key_options = prepare_upload(params)
        result[:resources_enabled] = !resource_params.nil?

        if params[:isTestFlight]
          upload_testflight(api_key_options, result)
        else
          upload_app_store(resource_params, api_key_options, result)
        end
      end

      # 上传前统一准备认证和资源，确保配置错误或资源缺失在 IPA 上传前被发现。
      def self.prepare_upload(params)
        resource_params = load_store_resources(params)
        api_key_options = AppStoreResourcesHelper.authentication_options(resource_params || {}, other_action)
        if resource_params
          resource_params.merge!(api_key_options)
          resource_params = AppStoreResourcesHelper.prepare(resource_params)
        end
        [resource_params, api_key_options]
      end

      # 只有显式开启的 App Store 流程读取资源配置，关闭时不解析路径或更新说明。
      def self.load_store_resources(params)
        config_path = AppStoreResourcesHelper.upload_config_path(params, app_store: !params[:isTestFlight])
        return nil unless config_path

        AppStoreResourcesHelper.load_params(
          app_store_resources_enabled: true,
          config_path: config_path,
          app_identifier: params[:app_identifier],
          app_version: params[:app_version],
          build_number: params[:build_number],
          release_notes: parse_release_notes(params[:release_notes])
        )
      end

      # 保留原 JSON 字符串接口；空值或无效 JSON 不覆盖资源文件中的更新说明。
      def self.parse_release_notes(value)
        JSON.parse(value || '')
      rescue JSON::ParserError, TypeError
        nil
      end

      # TestFlight 沿用现有上传方式，不执行 App Store 资源流程。
      def self.upload_testflight(api_key_options, result)
        UI.message('*************| 开始上传 TestFlight |*************')
        result[:stage] = '上传 TestFlight IPA'
        upload_result = other_action.upload_to_testflight({ skip_waiting_for_build_processing: true }.merge(api_key_options))
        result[:ipa_uploaded] = true
        upload_result
      end

      # 先上传 IPA，再处理已校验的资源；返回 IPA 上传结果以兼容已有 lane。
      def self.upload_app_store(resource_params, api_key_options, result)
        UI.message('*************| 开始上传 AppStore |*************')
        result[:stage] = '上传 App Store IPA'
        upload_options = app_store_upload_options(resource_params).merge(api_key_options)
        upload_result = other_action.upload_to_app_store(upload_options)
        result[:ipa_uploaded] = true
        if resource_params
          result[:stage] = '发布商店资源 / 选择构建 / 提交审核'
          # 新版本判断已在 IPA 上传前完成，之后直接使用确认过的资源上传开关。
          other_action.app_store_resources(resource_params.merge(upload_metadata_on_new_version: false))
          record_resource_result(result, resource_params)
        end
        upload_result
      end

      # 仅在整个资源 Action 成功返回后记录完成项，保持原 Action 的返回值不变。
      def self.record_resource_result(result, params)
        result.merge!(
          metadata_uploaded: params[:metadata_changed],
          screenshots_uploaded: params[:screenshots_changed],
          build_selected: params[:select_build] || params[:submit_for_review],
          review_submitted: params[:submit_for_review]
        )
      end

      # IPA 阶段始终关闭资源上传，避免默认目录或 Deliverfile 绕过资源总开关。
      def self.app_store_upload_options(resource_params)
        options = {
          skip_metadata: true,
          skip_screenshots: true,
          # deliver 的截图同步分支不受 skip_screenshots 控制，必须一并关闭。
          sync_screenshots: false,
          overwrite_screenshots: false,
          run_precheck_before_submit: false,
          precheck_include_in_app_purchases: false,
          force: true,
          submit_for_review: false,
          automatic_release: false
        }
        if resource_params
          options[:app_identifier] = resource_params[:app_identifier]
          options[:app_version] = resource_params[:app_version] if resource_params[:app_version]
        end
        options
      end

      private_class_method :prepare_upload, :load_store_resources, :parse_release_notes,
                           :upload_testflight, :upload_app_store, :app_store_upload_options, :record_resource_result

      def self.description
        "上传 AppStore"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :app_store_resources_enabled,
            env_name: 'APP_STORE_RESOURCES_ENABLED',
            description: '商店资源总开关，默认关闭；关闭时仅上传 IPA，不更新元数据或截图',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :release_notes,
            description: "更新文案, 格式为 { \"zh-Hans\": \"修复问题\", \"en-US\": \"bugfix\"} JSON 字符串",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :isTestFlight,
            description: "是否为 TestFlight 打包",
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :app_store_resources_config_path,
            env_name: 'APP_STORE_RESOURCES_CONFIG_PATH',
            description: 'App Store 资源发布 JSON 路径，开启商店资源总开关后必填',
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :app_identifier,
            description: '本次构建的 Bundle ID，覆盖资源配置',
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :app_version,
            description: '本次构建的版本号，覆盖资源配置',
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :build_number,
            description: '本次构建的 Build 号，覆盖资源配置',
            optional: true,
            type: String
          )
        ]
      end

      def self.is_supported?(platform)
        platform == :ios
      end

    end
  end
end
