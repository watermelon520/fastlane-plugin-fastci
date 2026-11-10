require 'fastlane/action'
require 'fastlane/plugin/fastci/helper/app_store_resources_helper'
include Fastlane::Helper

module Fastlane
  module Actions
    # 校验并上传 App Store Connect metadata 和截图
    class AppStoreResourcesAction < Action
      # 独立资源入口：准备资源 -> 上传 -> 可选构建选择 -> 可选提交审核，全程不上传 IPA。
      def self.run(params)
        return nil unless resources_enabled?(params)

        params = prepare_resources(params)
        upload_resources(params)
        select_build_and_submit_review(params)
      end

      # 总开关先于配置读取和认证检查，单独指定路径或资源子开关不能启用此能力。
      def self.resources_enabled?(params)
        return true if params[:app_store_resources_enabled] == true

        UI.message('*************| 商店资源功能未开启，跳过（APP_STORE_RESOURCES_ENABLED=false）|*************')
        false
      end

      # 统一读取配置、建立认证并准备资源目录，下载与校验规则由 Helper 负责。
      def self.prepare_resources(params)
        params = AppStoreResourcesHelper.load_params(params)
        params.merge!(AppStoreResourcesHelper.authentication_options(params, other_action))
        AppStoreResourcesHelper.prepare(params)
      end

      # 只上传配置指定的资源类别，无资源变化时跳过上传。
      def self.upload_resources(params)
        if params[:metadata_changed] || params[:screenshots_changed]
          UI.message('*************| 开始上传 App Store Connect 资源 |*************')
          other_action.upload_to_app_store(
            AppStoreResourcesHelper.resource_options(params, params[:metadata_path], params[:screenshots_path])
          )
          UI.success('App Store Connect 资源上传完成')
        else
          UI.message('*************| 没有 metadata 或截图变更，跳过资源上传 |*************')
        end
      end

      # 资源上传完成后，按配置选择精确构建并提交审核；两个步骤默认均不执行。
      def self.select_build_and_submit_review(params)
        # 提交审核也必须先确认精确构建，不能依赖 deliver 自动选择最新 Build。
        if params[:select_build] || params[:submit_for_review]
          AppStoreResourcesHelper.select_build(params)
        end

        if params[:submit_for_review]
          UI.message('*************| 开始提交 App Store 审核 |*************')
          other_action.upload_to_app_store(AppStoreResourcesHelper.review_options(params))
          UI.success('App Store 审核提交完成')
        end
      end

      private_class_method :resources_enabled?, :prepare_resources, :upload_resources, :select_build_and_submit_review

      def self.description
        '校验并上传 App Store Connect metadata 和截图'
      end

      # JSON 合并后也通过这组参数校验，使文件配置与直接调用拥有相同约束。
      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :app_store_resources_enabled,
            env_name: 'APP_STORE_RESOURCES_ENABLED',
            description: '商店资源总开关，必须显式开启后才能使用资源上传、下载及发布流程',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :config_path,
            env_name: 'APP_STORE_RESOURCES_CONFIG_PATH',
            description: '资源发布 JSON 配置文件路径，显式参数优先于配置文件',
            optional: true,
            default_value: nil,
            # 路径校验由开启后的 load_params 执行，关闭功能时不读取或校验资源文件。
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :app_identifier,
            description: 'App Store Connect App 的 Bundle ID',
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :app_version,
            description: '要更新的 App Store 版本号',
            optional: true,
            default_value: nil,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :metadata_path,
            description: 'metadata 目录路径',
            optional: true,
            default_value: 'fastlane/metadata',
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :screenshots_path,
            description: '截图目录路径',
            optional: true,
            default_value: 'fastlane/screenshots',
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :metadata_changed,
            description: '是否上传 metadata',
            optional: true,
            default_value: true,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :screenshots_changed,
            description: '是否上传截图',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :upload_metadata_on_new_version,
            description: '目标 App Store 版本不存在时是否强制上传 metadata',
            optional: true,
            default_value: true,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :download_missing_metadata,
            description: 'metadata 缺失时是否从 App Store Connect 下载',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :download_missing_screenshots,
            description: '截图缺失时是否从 App Store Connect 下载',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :use_live_version,
            description: '下载截图时是否使用线上版本',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :api_key,
            description: 'App Store Connect API Key Hash',
            optional: true,
            sensitive: true,
            type: Hash,
            conflicting_options: [:api_key_path]
          ),
          FastlaneCore::ConfigItem.new(
            key: :api_key_path,
            description: 'App Store Connect API Key JSON 文件路径',
            optional: true,
            type: String,
            conflicting_options: [:api_key],
            verify_block: proc do |value|
              UI.user_error!("API Key JSON 不存在: #{value}") unless File.file?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :username,
            description: 'Apple ID 用户名，仅在未提供 API Key 时使用',
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :platform,
            description: 'App Store Connect 平台',
            optional: true,
            default_value: 'ios',
            type: String,
            verify_block: proc { |value| UI.user_error!('资源上传仅支持 ios 平台') unless value == 'ios' }
          ),
          FastlaneCore::ConfigItem.new(
            key: :sync_screenshots,
            description: '是否让远端截图与本地截图同步',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :overwrite_screenshots,
            description: '上传前是否清空远端截图',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :submit_for_review,
            description: '上传资源后是否提交审核',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :automatic_release,
            description: '审核通过后是否自动发布',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :select_build,
            description: '是否按 app_version 和 build_number 自动选择构建',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :build_number,
            description: '要选择的精确 Build Number',
            optional: true,
            default_value: nil,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :wait_for_build_processing,
            description: '选择构建前是否等待 App Store Connect 处理完成',
            optional: true,
            default_value: true,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :build_processing_timeout,
            description: '等待构建处理完成的超时时间，单位秒',
            optional: true,
            default_value: 3600,
            type: Integer,
            verify_block: proc { |value| UI.user_error!('构建处理超时必须大于 0') unless value.positive? }
          ),
          FastlaneCore::ConfigItem.new(
            key: :build_processing_poll_interval,
            description: '查询构建处理状态的时间间隔，单位秒',
            optional: true,
            default_value: 30,
            type: Integer,
            verify_block: proc { |value| UI.user_error!('构建轮询间隔必须大于 0') unless value.positive? }
          ),
          FastlaneCore::ConfigItem.new(
            key: :build_processing_retry_limit,
            description: '查询构建处理状态遇到网络错误时的最大重试次数',
            optional: true,
            default_value: 3,
            type: Integer,
            verify_block: proc { |value| UI.user_error!('构建查询重试次数不能小于 0') if value.negative? }
          ),
          FastlaneCore::ConfigItem.new(
            key: :build_processing_retry_interval,
            description: '查询构建处理状态网络错误后的重试等待时间，单位秒',
            optional: true,
            default_value: 15,
            type: Integer,
            verify_block: proc { |value| UI.user_error!('构建查询重试间隔不能小于 0') if value.negative? }
          ),
          FastlaneCore::ConfigItem.new(
            key: :submission_information,
            description: 'deliver 提交审核信息，例如出口合规声明',
            optional: true,
            default_value: nil,
            type: Hash
          ),
          FastlaneCore::ConfigItem.new(
            key: :release_notes,
            description: '按语言配置的更新说明；优先于 metadata 中的 release_notes.txt',
            optional: true,
            type: Hash
          ),
          FastlaneCore::ConfigItem.new(
            key: :force,
            description: '是否跳过 HTML 预览确认',
            optional: true,
            default_value: true,
            type: Boolean
          )
        ]
      end

      def self.is_supported?(platform)
        platform == :ios
      end

      def self.category
        :production
      end
    end
  end
end
