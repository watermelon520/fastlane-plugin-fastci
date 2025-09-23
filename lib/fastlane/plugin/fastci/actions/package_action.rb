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
        configuration = params[:configuration] || "Debug"
        export_method = params[:export_method] || "development"
        build = params[:build] || nil
        version = params[:version] || nil
        is_analyze_swiftlint = params[:is_analyze_swiftlint] || false
        is_detect_duplicity_code = params[:is_detect_duplicity_code] || false
        is_detect_unused_code = params[:is_detect_unused_code] || false
        is_detect_unused_image = params[:is_detect_unused_image] || false
        if export_method == "app-store"
          configuration = "Release"
        end

        # 清理上一次的打包缓存
        FileUtils.rm_rf(Dir.glob("#{Constants.BUILD_LOG_DIR}/*"))
        FileUtils.rm_rf(Dir.glob("#{Constants.IPA_OUTPUT_DIR}/*"))
        
        # 安装证书
        other_action.install_certificate()
        # 安装 provisioningProfile
        other_action.install_profile()

        scheme = Environment.scheme

        # 更改项目version
        other_action.increment_version_number(
          version_number: version
        ) if CommonHelper.is_validate_string(version)

        # 更改项目build号
        UpdateBuildNumberAction.run(
          build: build
        )
        time = Time.new.strftime("%Y%m%d%H%M")
        version = Actions::GetVersionNumberAction.run(target: Environment.target)
        build = Actions::GetBuildNumberAction.run({})
        # 生成ipa包的名字格式
        ipaName = "#{Environment.scheme}_#{export_method}_#{version}_#{build}.ipa"
        
        # 获取 Extension 的 Bundle ID（可能有多个，用逗号分隔）
        extension_bundle_ids = Environment.extension_bundle_ids
        extension_profile_names = []
        # profile 名字
        profile_name = ""

        case export_method
        when "development"
          profile_name = Environment.provisioningProfiles_development
          extension_profile_names = Environment.extension_profiles_development
        when "ad-hoc"
          profile_name = Environment.provisioningProfiles_adhoc
          extension_profile_names = Environment.extension_profiles_adhoc
        when "app-store"
          profile_name = Environment.provisioningProfiles_appstore
          extension_profile_names = Environment.extension_profiles_appstore
        else
          raise "Unsupported export method: #{export_method}"
        end

        # 组装 provisioningProfiles 
        provisioningProfiles_map = {
          "#{Environment.bundleID}" => "#{profile_name}"
        }
        extension_bundle_ids.each_with_index do |ext_bundle_id, idx|
          provisioningProfiles_map[ext_bundle_id.strip] = extension_profile_names[idx]&.strip
        end

        UI.message("*************| 开始打包 |*************")

        other_action.gym(
          clean: true,
          silent: true,
          workspace: Environment.workspace,
          scheme: scheme,
          configuration: configuration,
          buildlog_path: Constants.BUILD_LOG_DIR,
          output_name: ipaName,
          output_directory: Constants.IPA_OUTPUT_DIR,
          export_options: {
            method: export_method,
            provisioningProfiles: provisioningProfiles_map
          }
        )

        UI.message("*************| 打包完成 |*************")

        UI.message("*************| 复制打包产物 |*************")
        # 定义桌面路径
        desktop_path = File.expand_path("~/Desktop")
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

        if export_method == "app-store"
          notiText = "🚀🚀🚀🚀🚀🚀\n\n#{scheme}-iOS-打包完成\n\n#{version}_#{build}_#{export_method}\n\n🚀🚀🚀🚀🚀🚀"
          DingdingHelper.sendMarkdown(notiText)

          if CommonHelper.is_validate_string(Environment.connect_key_id) && CommonHelper.is_validate_string(Environment.connect_issuer_id)

            other_action.upload_store()
            notiText = "🚀🚀🚀🚀🚀🚀\n\n#{scheme}-iOS-上传完成\n\n#{version}_#{build}_#{export_method}\n\n🚀🚀🚀🚀🚀🚀"
            DingdingHelper.sendMarkdown(notiText)
          end
        else
          # 钉钉通知
          notiText = "🚀🚀🚀🚀🚀🚀\n\n#{scheme}-iOS-打包完成\n\n#{version}_#{build}_#{export_method}\n\n🚀🚀🚀🚀🚀🚀"

          # 上传蒲公英
          if CommonHelper.is_validate_string(Environment.pgy_api_key)
            pgy_upload_info = other_action.upload_pgy()
            qrCode = pgy_upload_info["buildQRCodeURL"]

            if CommonHelper.is_validate_string(qrCode)
              notiText << "\n\n⬇️⬇️⬇️ 扫码安装 ⬇️⬇️⬇️\n\n\n密码: #{Environment.pgy_password}\n![screenshot](#{qrCode})"
            end
          end

          # 上传 fir
          if CommonHelper.is_validate_string(Environment.fir_api_token)
            fir_upload_info = other_action.upload_fir()
            download_url = fir_upload_info["download_url"]

            if CommonHelper.is_validate_string(download_url)
              notiText << "\n\n⬇️⬇️⬇️ 点击链接安装 ⬇️⬇️⬇️\n\n\n密码: #{Environment.fir_password}\n[_点击下载_](#{download_url})"
            end
          end

          DingdingHelper.sendMarkdown(notiText)
        end

        # 代码分析
        if is_analyze_swiftlint && export_method != "app-store"
          analyze_swiftlint(is_from_package: true, configuration: configuration)
          # 结果复制到桌面
          FileUtils.cp(SWIFTLINT_HTML_FILE, target_path)
          FileUtils.cp(SWIFTLINT_ANALYZE_HTML_FILE, target_path)
          UI.message("*************| 代码分析完成 |*************")
        else
          UI.message("*************| 跳过代码分析 |*************")
        end

        # 重复代码检查
        if is_detect_duplicity_code && export_method != "app-store"
          detect_code_duplicity(is_all: true)
          # 结果复制到桌面
          FileUtils.cp(DUPLICITY_CODE_HTML_FILE, target_path)
          UI.message("*************| 重复代码检查完成 |*************")
        else
          UI.message("*************| 跳过重复代码检查 |*************")
        end

        # 无用代码检查
        if is_detect_unused_code && export_method != "app-store"
          DetectUnusedCodeAction.run(
            is_from_package: true,
            configuration: configuration
          )
          # 结果复制到桌面
          FileUtils.cp(Constants.UNUSED_CODE_HTML_FILE, target_path)
          UI.message("*************| 无用代码检查完成 |*************")
        else
          UI.message("*************| 跳过无用代码检查 |*************")
        end

        # 无用图片检查
        if is_detect_unused_image && export_method != "app-store"
          DetectUnusedImageAction.run({})
          # 结果复制到桌面
          FileUtils.cp(Constants.UNUSED_IMAGE_HTML_FILE, target_path)
          UI.message("*************| 无用图片检查完成 |*************")
        else
          UI.message("*************| 跳过未使用图片检查 |*************")
        end

        if is_analyze_swiftlint ||
          is_detect_duplicity_code ||
          is_detect_unused_code ||
          is_detect_unused_image
          # 钉钉通知
          notiText = "🚀🚀🚀🚀🚀🚀\n\n#{scheme}-iOS-代码检查完成\n\n#{version}_#{build}_#{export_method}\n\n🚀🚀🚀🚀🚀🚀"
          DingdingHelper.sendMarkdown(notiText)
        else
          UI.message("*************| 跳过代码检查 |*************")
        end

        UI.message("*************| 脚本完成 |*************")
      end

      def self.description
        "打包"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :configuration,
            description: "编译环境 Release or Debug",
            optional: true,
            default_value: "Debug",
            type: String,
            verify_block: proc do |value|
              valid_params = ["Release", "Debug"]
              unless valid_params.include?(value)
                UI.user_error!("无效的编译环境: #{value}。支持的环境: #{valid_params.join(', ')}")
              end
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :export_method,
            description: "打包方式 ad-hoc, enterprise, app-store, development",
            optional: true,
            default_value: "development",
            type: String,
            verify_block: proc do |value|
              valid_params = ["ad-hoc", "enterprise", "app-store", "development"]
              unless valid_params.include?(value)
                UI.user_error!("无效的打包方式: #{value}。支持的方式: #{valid_params.join(', ')}")
              end
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :version,
            description: "自定义 `version`。在 Xcode13 之后创建的项目，不再支持脚本修改。需要兼容请在 Build settings 中将 GENERATE_INFOPLIST_FILE 设置为 NO",
            optional: true,
            default_value: nil,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :build,
            description: "不采取自动更新，自定义 `build` 号",
            optional: true,
            default_value: nil,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :is_analyze_swiftlint,
            description: "是否代码分析",
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :is_detect_duplicity_code,
            description: "是否检查重复代码",
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :is_detect_unused_code,
            description: "是否检查无用代码",
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :is_detect_unused_image,
            description: "是否检查无用图片",
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :release_notes,
            description: "更新文案, 格式为 { \"zh-Hans\" => \"修复问题\", \"en-US\" => \"bugfix\"} ",
            optional: true,
            type: Hash
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