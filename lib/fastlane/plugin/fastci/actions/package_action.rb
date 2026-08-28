require 'gym'
require 'fastlane_core'
require 'fastlane/action'
include Fastlane::Helper

module Fastlane
  module Actions
    # 打包
    class PackageAction < Action
      def self.run(params)
        # 入参配置
        configuration = params[:configuration] || 'Debug'
        export_method = params[:export_method] || 'development'
        build = params[:build] || nil
        version = params[:version] || nil
        is_analyze_swiftlint = params[:is_analyze_swiftlint] || false
        is_detect_duplicity_code = params[:is_detect_duplicity_code] || false
        is_detect_unused_code = params[:is_detect_unused_code] || false
        is_detect_unused_image = params[:is_detect_unused_image] || false
        release_notes = params[:release_notes] || ''
        app_store_resources_config_path = params[:app_store_resources_config_path]
        testflight_config_path = params[:testflight_config_path]
        testflight_params = {}
        if export_method == 'testFlight'
          testflight_params = AppStoreResourcesHelper.load_testflight_params(params)
          build = testflight_params[:testflight_build_number] if testflight_params[:testflight_build_number]
          release_notes = testflight_params[:changelog] if release_notes.to_s.empty? && testflight_params[:changelog]
        end
        configuration = 'Release' if %w[app-store testFlight].include?(export_method)
        is_notice_dingding = params[:is_notice_dingding].nil? ? true : params[:is_notice_dingding]
        # 统一发送钉钉消息匿名函数
        send_dingding_notice = lambda do |text|
          if is_notice_dingding
            DingdingHelper.sendMarkdown(text)
          else
            UI.message('*************| 跳过钉钉消息通知（is_notice_dingding=false）|*************')
          end
        end
        send_dingding_notice.call('测试一下')
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
        time = Time.new.strftime('%Y%m%d%H%M')

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

        other_action.gym(gym_options)

        UI.message('*************| 打包完成 |*************')

        UI.message('*************| 复制打包产物 |*************')
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

        if gym_method == 'app-store'
          notiText = "🚀🚀🚀🚀🚀🚀\n\n#{scheme}-iOS-打包完成\n\n#{version}_#{build}_#{export_method}\n\n🚀🚀🚀🚀🚀🚀"
          send_dingding_notice.call(notiText)

          has_p8_api_key = CommonHelper.is_validate_string(Environment.connect_key_id) &&
            CommonHelper.is_validate_string(Environment.connect_issuer_id)
          has_api_key_json = CommonHelper.is_validate_string(Environment.app_store_connect_api_key_path)
          if has_p8_api_key || has_api_key_json
            # 根据 export_method 决定是否为 TestFlight
            is_test_flight = export_method == 'testFlight'

            metadata_required_for_new_version = false
            unless is_test_flight || app_store_resources_config_path.to_s.empty?
              resource_params = AppStoreResourcesHelper.load_params(
                config_path: app_store_resources_config_path,
                app_identifier: Environment.bundleID,
                app_version: version.to_s,
                build_number: build.to_s
              )
              metadata_required_for_new_version =
                AppStoreResourcesHelper.metadata_required_for_new_version?(resource_params)
              UI.message(
                "目标 App Store 版本 #{version} #{metadata_required_for_new_version ? '不存在，将强制上传 metadata' : '已存在，按资源变更配置处理'}"
              )
            end

            other_action.upload_store(
              release_notes: release_notes,
              isTestFlight: is_test_flight,
              skip_metadata: !app_store_resources_config_path.to_s.empty?,
              testflight_changelog: testflight_params[:changelog],
              testflight_distribute_external: testflight_params[:distribute_external],
              testflight_notify_external_testers: testflight_params[:notify_external_testers],
              testflight_submit_beta_review: testflight_params[:submit_beta_review],
              testflight_groups: testflight_params[:groups]
            )

            if is_test_flight && testflight_params[:testflight_build_number]
              AppStoreResourcesHelper.verify_testflight_build(
                testflight_params.merge(
                  app_identifier: Environment.bundleID,
                  app_version: version.to_s,
                  testflight_build_number: build.to_s
                )
              )
            elsif !is_test_flight && !app_store_resources_config_path.to_s.empty?
              resource_options = {
                config_path: app_store_resources_config_path,
                app_identifier: Environment.bundleID,
                app_version: version.to_s,
                build_number: build.to_s,
                select_build: params[:select_build_after_upload]
              }
              resource_options[:metadata_changed] = true if metadata_required_for_new_version
              other_action.app_store_resources(
                resource_options
              )
            end
            notiText = "🚀🚀🚀🚀🚀🚀\n\n#{scheme}-iOS-上传完成\n\n#{version}_#{build}_#{export_method}\n\n🚀🚀🚀🚀🚀🚀"
            send_dingding_notice.call(notiText)
          end
        else
          # 钉钉通知
          notiText = "🚀🚀🚀🚀🚀🚀\n\n#{scheme}-iOS-打包完成\n\n#{version}_#{build}_#{export_method}\n\n🚀🚀🚀🚀🚀🚀"

          # 上传蒲公英
          if CommonHelper.is_validate_string(Environment.pgy_api_key)
            pgy_upload_info = other_action.upload_pgy
            qrCode = pgy_upload_info['buildQRCodeURL']

            if CommonHelper.is_validate_string(qrCode)
              notiText << "\n\n⬇️⬇️⬇️ 扫码安装 ⬇️⬇️⬇️\n\n\n密码: #{Environment.pgy_password}\n![screenshot](#{qrCode})"
            end
          end

          # 上传 fir
          if CommonHelper.is_validate_string(Environment.fir_api_token)
            fir_upload_info = other_action.upload_fir(
              changelog: params[:changelog]
            )
            download_url = fir_upload_info[:download_url]

            if CommonHelper.is_validate_string(download_url)
              notiText << "\n\n⬇️⬇️⬇️ 点击链接安装 ⬇️⬇️⬇️\n\n\n密码: #{Environment.fir_password}\n[_点击下载_](#{download_url})"
            end
          end

          send_dingding_notice.call(notiText)
        end

        # Sentry 上传 dSYM
        if CommonHelper.is_validate_string(Environment.sentry_auth_token)
          other_action.sentry_upload_dsym
        else
          UI.message('*************| 未配置 Sentry 跳过 dSYM 上传 |*************')
        end

        # 代码分析
        if is_analyze_swiftlint && gym_method != 'app-store'
          other_action.analyze_swiftlint(
            is_from_package: true,
            configuration: configuration
          )
          # 结果复制到桌面
          FileUtils.cp(SWIFTLINT_ANALYZE_HTML_FILE, target_path)
          UI.message('*************| 代码分析完成 |*************')
        else
          UI.message('*************| 跳过代码分析 |*************')
        end

        # 重复代码检查
        if is_detect_duplicity_code && gym_method != 'app-store'
          other_action.detect_duplicity_code(
            is_all: true
          )
          # 结果复制到桌面
          FileUtils.cp(DUPLICITY_CODE_HTML_FILE, target_path)
          UI.message('*************| 重复代码检查完成 |*************')
        else
          UI.message('*************| 跳过重复代码检查 |*************')
        end

        # 无用代码检查
        if is_detect_unused_code && gym_method != 'app-store'
          other_action.detect_unused_code(
            scheme: scheme,
            is_from_package: true,
            configuration: configuration
          )
          # 结果复制到桌面
          FileUtils.cp(Constants.UNUSED_CODE_HTML_FILE, target_path)
          UI.message('*************| 无用代码检查完成 |*************')
        else
          UI.message('*************| 跳过无用代码检查 |*************')
        end

        # 无用图片检查
        if is_detect_unused_image && gym_method != 'app-store'
          other_action.detect_unused_image
          # 结果复制到桌面
          FileUtils.cp(Constants.UNUSED_IMAGE_HTML_FILE, target_path)
          UI.message('*************| 无用图片检查完成 |*************')
        else
          UI.message('*************| 跳过未使用图片检查 |*************')
        end

        if is_analyze_swiftlint ||
           is_detect_duplicity_code ||
           is_detect_unused_code ||
           is_detect_unused_image
          # 钉钉通知
          notiText = "🚀🚀🚀🚀🚀🚀\n\n#{scheme}-iOS-代码检查完成\n\n#{version}_#{build}_#{export_method}\n\n🚀🚀🚀🚀🚀🚀"
          send_dingding_notice.call(notiText)
        else
          UI.message('*************| 跳过代码检查 |*************')
        end

        UI.message('*************| 脚本完成 |*************')
      end

      def self.description
        '打包'
      end

      def self.available_options
        [
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
            key: :app_store_resources_config_path,
            description: 'App Store 资源、构建选择和审核提交 JSON 配置文件路径；仅用于 app-store',
            optional: true,
            default_value: nil,
            type: String,
            verify_block: proc do |value|
              UI.user_error!("App Store 资源配置文件不存在: #{value}") unless File.file?(File.expand_path(value))
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :select_build_after_upload,
            description: 'IPA 上传后是否自动选择本次构建；未配置时由资源 JSON 的 select_build 控制',
            optional: true,
            default_value: nil,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :testflight_config_path,
            description: 'TestFlight 测试内容、Build 校验和分发配置文件路径；仅用于 testFlight',
            optional: true,
            default_value: nil,
            type: String,
            verify_block: proc do |value|
              UI.user_error!("TestFlight 配置文件不存在: #{value}") unless File.file?(File.expand_path(value))
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :testflight_build_number,
            description: 'TestFlight 专用 Build Number；优先使用 testflight_config_path 中的配置',
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
            description: '是否自动分发 TestFlight 构建到外部测试组，默认关闭',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :testflight_notify_external_testers,
            description: '分发 TestFlight 构建时是否通知外部测试人员，默认关闭',
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
