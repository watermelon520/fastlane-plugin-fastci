require 'fastlane/action'
include Fastlane::Helper

module Fastlane
  module Actions
    # 上传 AppStore
    class UploadStoreAction < Action
      def self.run(params)

        release_notes = JSON.parse(params[:release_notes] || "") rescue nil

        api_key_options = {}
        if CommonHelper.is_validate_string(Environment.app_store_connect_api_key_path)
          api_key_options[:api_key_path] = Environment.app_store_connect_api_key_path
        else
          other_action.app_store_connect_api_key(
            key_id: Environment.connect_key_id,
            issuer_id: Environment.connect_issuer_id,
            key_filepath: File.expand_path(Environment.app_store_connect_p8_path),
            duration: 1200, # optional (maximum 1200)
            in_house: false # optional but may be required if using match/sigh
          )
        end

        if params[:isTestFlight]
          UI.message("*************| 开始上传 TestFlight |*************")
          upload_options = {
            # 测试内容只能在 Build 处理完成后写入；无测试内容且不分发外测时才可提前结束。
            skip_waiting_for_build_processing: params[:testflight_changelog].to_s.empty? && !params[:testflight_distribute_external],
            distribute_external: params[:testflight_distribute_external],
            notify_external_testers: params[:testflight_notify_external_testers],
            submit_beta_review: params[:testflight_submit_beta_review]
          }
          upload_options[:changelog] = params[:testflight_changelog] if params[:testflight_changelog].to_s.length > 0
          upload_options[:groups] = params[:testflight_groups] if params[:testflight_groups]
          other_action.upload_to_testflight(upload_options.merge(api_key_options))
        else
          UI.message("*************| 开始上传 AppStore |*************")
          
          # 构建上传参数，只有当 release_notes 有效时才添加
          upload_options = {
            skip_metadata: params[:skip_metadata],
            skip_screenshots: true,
            run_precheck_before_submit: false,
            precheck_include_in_app_purchases: false,
            force: true,
            submit_for_review: false,
            automatic_release: false
          }
          
          # 只有当 release_notes 不为 nil 且不为空时才添加
          if release_notes && !release_notes.empty?
            upload_options[:release_notes] = release_notes
          end
          
          other_action.upload_to_app_store(upload_options.merge(api_key_options))
        end
      end

      def self.description
        "上传 AppStore"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :release_notes,
            description: "更新文案, 格式为 { \"zh-Hans\": \"修复问题\", \"en-US\": \"bugfix\"} JSON 字符串",
            optional: false,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :isTestFlight,
            description: "是否为 TestFlight 打包",
            optional: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :skip_metadata,
            description: '上传 IPA 时是否跳过 metadata，资源由 app_store_resources 管理时应开启',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :testflight_changelog,
            description: 'TestFlight 测试内容（What to Test）',
            optional: true,
            default_value: nil,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :testflight_distribute_external,
            description: '是否将 TestFlight 构建分发给外部测试组，默认关闭',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :testflight_notify_external_testers,
            description: '分发到外部测试组时是否通知测试人员，默认关闭',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :testflight_submit_beta_review,
            description: '是否自动提交 TestFlight Beta 审核；关闭后需在 App Store Connect 手动提交，默认开启',
            optional: true,
            default_value: true,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :testflight_groups,
            description: 'TestFlight 外部测试组名称或 ID 列表',
            optional: true,
            default_value: nil,
            type: Array
          )
        ]
      end

      def self.is_supported?(platform)
        platform == :ios
      end

    end
  end
end
