require 'gym'
require 'fastlane_core'
require 'fastlane/action'
require 'fastlane/plugin/fastci/helper/app_store_resources_helper'
require 'fastlane/plugin/fastci/helper/package_notification_helper'
include Fastlane::Helper

module Fastlane
  module Actions
    # 打包
    class PackageAction < Action
      def self.run(params)
        notice = PackageNotificationHelper.new(params)
        # 入参配置
        configuration = params[:configuration] || 'Debug'
        export_method = params[:export_method] || 'development'
        build = params[:build] || nil
        version = params[:version] || nil
        testflight_params = export_method == 'testFlight' ? AppStoreResourcesHelper.load_testflight_params(params) : {}
        build = testflight_params[:testflight_build_number] if export_method == 'testFlight' && testflight_params[:testflight_build_number]
        store_options = store_upload_options(params, export_method, testflight_params)
        configuration = 'Release' if %w[app-store testFlight].include?(export_method)
        # 清理上一次的打包缓存
        FileUtils.rm_rf(Dir.glob("#{Constants.BUILD_LOG_DIR}/*"))
        FileUtils.rm_rf(Dir.glob("#{Constants.IPA_OUTPUT_DIR}/*"))

        # 非自动更新模式下，安装证书和 provisioningProfile
        unless Environment.is_auto_update_provisioning
          other_action.install_certificate
          other_action.install_profile
        end

        scheme = params[:scheme] || Environment.scheme

        # 更改项目version
        if CommonHelper.is_validate_string(version)
          increment_options = { version_number: version }
          increment_options[:xcodeproj] = Environment.project if CommonHelper.is_validate_string(Environment.project)
          other_action.increment_version_number(increment_options)
        end

        # 更改项目build号
        other_action.update_build_number(
          build: build
        )

        # 获取版本号
        version_options = { target: scheme }
        version_options[:xcodeproj] = Environment.project if CommonHelper.is_validate_string(Environment.project)
        version = other_action.get_version_number(version_options)

        # 获取 build 号
        build_options = {}
        build_options[:xcodeproj] = Environment.project if CommonHelper.is_validate_string(Environment.project)
        build = other_action.get_build_number(build_options)
        # 生成ipa包的名字格式
        ipaName = "#{scheme}_#{export_method}_#{version}_#{build}.ipa"
        notice.build_info(version: version, build: build)

        # 获取 Extension 的 Bundle ID（可能有多个，用逗号分隔）
        extension_bundle_ids = Environment.extension_bundle_ids
        extension_profile_names = []
        # profile 名字
        profile_name = ''

        case export_method
        when 'development'
          profile_name = Environment.provisioningProfiles_development
          extension_profile_names = Environment.extension_profiles_development
        when 'ad-hoc'
          profile_name = Environment.provisioningProfiles_adhoc
          extension_profile_names = Environment.extension_profiles_adhoc
        when 'app-store', 'testFlight'
          profile_name = Environment.provisioningProfiles_appstore
          extension_profile_names = Environment.extension_profiles_appstore
        else
          raise "Unsupported export method: #{export_method}"
        end

        UI.message('*************| 开始打包 |*************')

        # 组装 provisioningProfiles
        provisioningProfiles_map = {
          "#{Environment.bundleID}" => "#{profile_name}"
        }
        extension_bundle_ids.each_with_index do |ext_bundle_id, idx|
          provisioningProfiles_map[ext_bundle_id.strip] = extension_profile_names[idx]&.strip
        end

        # 对于 testFlight，使用 app-store 方法
        gym_method = export_method == 'testFlight' ? 'app-store' : export_method

        gym_options = {
          clean: true,
          silent: true,
          workspace: Environment.workspace,
          scheme: scheme,
          configuration: configuration,
          buildlog_path: Constants.BUILD_LOG_DIR,
          output_name: ipaName,
          output_directory: Constants.IPA_OUTPUT_DIR,
          export_options: {
            method: gym_method
          }
        }

        if Environment.is_auto_update_provisioning
          gym_options[:xcargs] = '-allowProvisioningUpdates'
        else
          gym_options[:export_options][:provisioningProfiles] = provisioningProfiles_map
        end

        notice.stage(:local, '构建 IPA')
        other_action.gym(gym_options)

        UI.message('*************| 打包完成 |*************')

        UI.message('*************| 复制打包产物 |*************')
        notice.stage(:local, '复制构建产物')
        # 定义桌面路径
        desktop_path = File.expand_path('~/Desktop')
        output_path = File.join(desktop_path, "BuildOutput_#{scheme}")
        target_path = File.join(output_path, "#{build}")
        FileUtils.mkdir_p(target_path)
        # 构建复制到桌面
        Dir.glob("#{Constants.IPA_OUTPUT_DIR}/*").each do |file|
          UI.message("准备复制文件：#{file} 到 #{target_path}")
          FileUtils.cp_r(file, target_path)
        end

        # UI.message("*************| 重置 Git 仓库 |*************")
        # 重置 Git 仓库
        # system("git reset --hard")

        ipa_path = "#{Constants.IPA_OUTPUT_DIR}/#{ipaName}"
        # 构建完成仅记录终端日志，钉钉成功通知由各分发平台上传结果触发。
        distribute_package(params, notice, store_options, ipa_path: ipa_path, version: version, build: build)

        # Sentry 上传 dSYM
        if CommonHelper.is_validate_string(Environment.sentry_auth_token)
          notice.stage(:sentry, '上传 dSYM')
          other_action.sentry_upload_dsym
        else
          UI.message('*************| 未配置 Sentry 跳过 dSYM 上传 |*************')
        end

        run_package_checks(params, notice, gym_method: gym_method, scheme: scheme,
                           configuration: configuration, target_path: target_path)

        UI.message('*************| 脚本完成 |*************')
      rescue StandardError
        notice&.failure(store_result: Actions.lane_context[SharedValues::FASTCI_STORE_UPLOAD_RESULT] || {})
        raise
      end

      # 各平台分别发送结果；后一个平台失败时，已经成功的平台仍有明确通知。
      def self.distribute_package(params, notice, store_options, ipa_path:, version:, build:)
        if %w[app-store testFlight].include?(params[:export_method])
          platform = params[:export_method] == 'testFlight' ? :testflight : :app_store
          notice.stage(platform, '准备商店上传')
          Actions.lane_context.delete(SharedValues::FASTCI_STORE_UPLOAD_RESULT)
          if upload_store_if_configured(store_options, version: version, build: build)
            result = Actions.lane_context[SharedValues::FASTCI_STORE_UPLOAD_RESULT] || {}
            notice.distribution_completed(platform, { uploaded: true }, store_result: result)
          else
            notice.store_skipped(platform)
          end
        else
          distribute_test_package(params, notice, ipa_path)
        end
      end

      # 保持原有上传顺序与开关；安装链接的整理交给通知 Helper。
      def self.distribute_test_package(params, notice, ipa_path)
        if CommonHelper.is_validate_string(Environment.pgy_api_key)
          notice.stage(:pgy, '上传 IPA')
          notice.distribution_completed(:pgy, other_action.upload_pgy)
        end
        if CommonHelper.is_validate_string(Environment.fir_api_token)
          notice.stage(:fir, '上传 IPA')
          notice.distribution_completed(:fir, other_action.upload_fir(changelog: params[:changelog]))
        end
        return unless CommonHelper.is_validate_string(Environment.zealot_token)

        notice.stage(:zealot, '上传 IPA')
        result = other_action.upload_zealot(file: ipa_path, changelog: params[:changelog])
        if result && params[:is_upload_zealot_dsym]
          notice.stage(:zealot, '上传 dSYM（IPA 已上传）')
          other_action.upload_zealot_dsym
          result = result.merge(dsym_status: Actions.lane_context[SharedValues::ZEAALOT_ERROR_MESSAGE] ? '上传未完成' : '已上传')
        end
        notice.distribution_completed(:zealot, result)
      end

      # 仅统计实际调用的检查，商店包跳过检查时不发送“检查完成”。
      def self.run_package_checks(params, notice, gym_method:, scheme:, configuration:, target_path:)
        return if gym_method == 'app-store'

        checks = [
          [:is_analyze_swiftlint, 'SwiftLint', :analyze_swiftlint,
           { is_from_package: true, configuration: configuration }, Constants.SWIFTLINT_ANALYZE_HTML_FILE],
          [:is_detect_duplicity_code, '重复代码', :detect_duplicity_code,
           { is_all: true }, Constants.DUPLICITY_CODE_HTML_FILE],
          [:is_detect_unused_code, '无用代码', :detect_unused_code,
           { scheme: scheme, is_from_package: true, configuration: configuration }, Constants.UNUSED_CODE_HTML_FILE],
          [:is_detect_unused_image, '无用图片', :detect_unused_image, {}, Constants.UNUSED_IMAGE_HTML_FILE]
        ]
        completed = []
        checks.each do |key, name, action, options, report|
          next unless params[key]

          notice.stage(:checks, name)
          options.empty? ? other_action.public_send(action) : other_action.public_send(action, **options)
          FileUtils.cp(report, target_path)
          completed << name
        end
        notice.checks_completed(completed)
      end

      private_class_method :distribute_package, :distribute_test_package, :run_package_checks

      # 构建前准备商店上传参数，开启资源功能却漏配路径时立即报错。
      def self.store_upload_options(params, export_method, testflight_params = {})
        if export_method == 'testFlight'
          return {
            release_notes: params[:release_notes] || '',
            isTestFlight: true,
            # TestFlight 不进入商店资源流程，显式传递 nil 防止下层环境配置误开启资源发布。
            app_store_resources_enabled: nil,
            app_identifier: Environment.bundleID,
            testflight_config_path: params[:testflight_config_path],
            api_key: testflight_params[:api_key],
            api_key_path: testflight_params[:api_key_path],
            username: testflight_params[:username],
            testflight_build_number: testflight_params[:testflight_build_number],
            testflight_changelog: testflight_params[:changelog],
            testflight_distribute_external: testflight_params[:distribute_external],
            testflight_notify_external_testers: testflight_params[:notify_external_testers],
            testflight_submit_beta_review: testflight_params[:submit_beta_review],
            testflight_groups: testflight_params[:groups]
          }
        end

        config_path = AppStoreResourcesHelper.upload_config_path(params, app_store: true)
        options = {
          release_notes: params[:release_notes] || '',
          isTestFlight: false,
          # 显式透传 false，避免下层 Action 从环境变量重新开启本次已关闭的功能。
          app_store_resources_enabled: !config_path.nil?
        }
        options[:app_store_resources_config_path] = config_path if config_path
        options
      end

      # 根据凭据或已开启的资源配置判断是否上传，单独存在资源路径不能触发上传。
      def self.store_upload_configured?(options)
        has_p8_key = CommonHelper.is_validate_string(Environment.connect_key_id) &&
          CommonHelper.is_validate_string(Environment.connect_issuer_id)
        has_api_key_json = CommonHelper.is_validate_string(Environment.app_store_connect_api_key_path)
        options[:isTestFlight] || has_p8_key || has_api_key_json || options[:app_store_resources_enabled]
      end

      # 上传本次产物，并返回是否执行了上传，供主流程决定是否发送完成通知。
      def self.upload_store_if_configured(options, version:, build:)
        return false unless store_upload_configured?(options)

        upload_options = options.dup
        if upload_options[:app_store_resources_enabled]
          # 使用真实产物信息覆盖资源配置，避免选中 JSON 中残留的旧版本或 Build。
          upload_options.merge!(
            app_identifier: Environment.bundleID,
            app_version: version.to_s,
            build_number: build.to_s
          )
        elsif upload_options[:isTestFlight]
          # TestFlight 只使用独立配置和本次产物的精确版本/Build，不读取商店资源 JSON。
          upload_options.merge!(
            app_identifier: Environment.bundleID,
            app_version: version.to_s,
            testflight_build_number: build.to_s
          )
        end
        other_action.upload_store(upload_options)
        true
      end

      private_class_method :store_upload_options, :store_upload_configured?, :upload_store_if_configured

      def self.description
        '打包'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :app_store_resources_enabled,
            env_name: 'APP_STORE_RESOURCES_ENABLED',
            description: '商店资源总开关，默认关闭，仅 app-store 打包时生效',
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
            key: :is_upload_zealot_dsym,
            env_name: 'ZEALOT_UPLOAD_DSYM',
            description: 'IPA 上传 Zealot 成功后继续上传 iOS dSYM',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :scheme,
            description: '不采取默认配置，自定义 `scheme` 名称',
            optional: true,
            default_value: nil,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :configuration,
            description: '编译环境 Release or Debug',
            optional: true,
            default_value: 'Debug',
            type: String,
            verify_block: proc do |value|
              valid_params = %w[Release Debug]
              UI.user_error!("无效的编译环境: #{value}。支持的环境: #{valid_params.join(', ')}") unless valid_params.include?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :export_method,
            description: '打包方式 ad-hoc, enterprise, app-store, development, testFlight',
            optional: true,
            default_value: 'development',
            type: String,
            verify_block: proc do |value|
              valid_params = %w[ad-hoc enterprise app-store development testFlight]
              UI.user_error!("无效的打包方式: #{value}。支持的方式: #{valid_params.join(', ')}") unless valid_params.include?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :version,
            description: '自定义 `version`。在 Xcode13 之后创建的项目，不再支持脚本修改。需要兼容请在 Build settings 中将 GENERATE_INFOPLIST_FILE 设置为 NO',
            optional: true,
            default_value: nil,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :build,
            description: '不采取自动更新，自定义 `build` 号',
            optional: true,
            default_value: nil,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :is_analyze_swiftlint,
            description: '是否代码分析',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :is_detect_duplicity_code,
            description: '是否检查重复代码',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :is_detect_unused_code,
            description: '是否检查无用代码',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :is_detect_unused_image,
            description: '是否检查无用图片',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :changelog,
            description: '更新日志',
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :release_notes,
            description: '更新文案, 格式为 { "zh-Hans": "修复问题", "en-US": "bugfix"} JSON 字符串',
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :testflight_config_path,
            description: 'TestFlight 测试内容、Build 校验和分发配置文件路径；仅用于 testFlight',
            optional: true,
            default_value: nil,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :testflight_build_number,
            description: 'TestFlight 专用 Build Number；优先使用配置文件',
            optional: true,
            default_value: nil,
            type: String
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
            description: '是否将 TestFlight 构建分发给外部测试组',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :testflight_notify_external_testers,
            description: '分发到外部测试组时是否通知测试人员',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :testflight_submit_beta_review,
            description: '是否自动提交 TestFlight Beta 审核',
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
          ),
          FastlaneCore::ConfigItem.new(
            key: :is_notice_dingding,
            description: '是否通知钉钉(默认true, 优先级高于DINGDING_TOKEN)',
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
        :building
      end
    end
  end
end
