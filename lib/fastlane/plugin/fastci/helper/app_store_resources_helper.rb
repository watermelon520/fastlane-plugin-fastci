require 'fileutils'
require 'json'
require 'timeout'

module Fastlane
  module Helper
    # App Store Connect 资源发布辅助方法
    class AppStoreResourcesHelper
      # deliver 使用按语言分目录的文本文件保存商店文案及审核信息。
      METADATA_FILE_PATTERN = '*.txt'

      # 只接受通用发布字段，拼写错误或业务项目的嵌套配置应直接报错。
      # 总开关由环境变量或 Action 参数控制，不允许资源 JSON 自行开启功能。
      CONFIG_KEYS = %i[
        app_identifier
        app_version
        metadata_path
        screenshots_path
        metadata_changed
        screenshots_changed
        upload_metadata_on_new_version
        download_missing_metadata
        download_missing_screenshots
        use_live_version
        api_key
        api_key_path
        username
        platform
        sync_screenshots
        overwrite_screenshots
        submit_for_review
        automatic_release
        select_build
        build_number
        wait_for_build_processing
        build_processing_timeout
        build_processing_poll_interval
        build_processing_retry_limit
        build_processing_retry_interval
        submission_information
        release_notes
        force
      ].freeze

      # 同时支持普通 Hash 和 Fastlane Configuration；默认值与 Action 参数声明保持一致。
      # 总开关开启后默认只更新元数据，截图替换、构建选择和审核发布仍需配置开启。
      DEFAULT_PARAMS = {
        metadata_path: 'fastlane/metadata',
        screenshots_path: 'fastlane/screenshots',
        metadata_changed: true,
        screenshots_changed: false,
        upload_metadata_on_new_version: true,
        download_missing_metadata: false,
        download_missing_screenshots: false,
        use_live_version: false,
        platform: 'ios',
        sync_screenshots: false,
        overwrite_screenshots: false,
        submit_for_review: false,
        automatic_release: false,
        select_build: false,
        wait_for_build_processing: true,
        build_processing_timeout: 3600,
        build_processing_poll_interval: 30,
        build_processing_retry_limit: 3,
        build_processing_retry_interval: 15,
        force: true
      }.freeze

      # 打包和 IPA 上传共用的资源入口校验；关闭总开关或非 App Store 时不读取路径。
      def self.upload_config_path(params, app_store:)
        return nil unless app_store && params[:app_store_resources_enabled] == true

        path = params[:app_store_resources_config_path]
        UI.user_error!('开启商店资源功能后必须配置 APP_STORE_RESOURCES_CONFIG_PATH') if path.to_s.strip.empty?
        path
      end

      # 合并并校验配置，优先级为显式参数 > JSON > 默认值，返回规范化后的 Hash。
      def self.load_params(params)
        config_path = params[:config_path]
        config = {}
        unless config_path.to_s.strip.empty?
          config_path = File.expand_path(config_path)
          UI.user_error!("资源配置文件不存在: #{config_path}") unless File.file?(config_path)
          config = JSON.parse(File.read(config_path))
          UI.user_error!("资源配置文件必须是扁平 JSON 对象: #{config_path}") unless config.is_a?(Hash)
        end

        config = config.each_with_object({}) do |(key, value), values|
          symbol_key = key.to_sym
          UI.user_error!("资源配置包含不支持的字段: #{key}") unless CONFIG_KEYS.include?(symbol_key)
          values[symbol_key] = value
        end

        # _values 只包含调用者传入的值，避免 Action 默认值覆盖 JSON 中的 false。
        explicit_values = if params.respond_to?(:_values)
                            params._values
                          else
                            params
                          end
        explicit_values = explicit_values.reject { |_key, value| value.nil? }
        values = DEFAULT_PARAMS.merge(config).merge(explicit_values)
        values[:config_path] = config_path unless config_path.to_s.strip.empty?
        values[:app_identifier] ||= Environment.bundleID
        # JSON 同样经过 Fastlane 的类型、冲突和路径校验，避免字符串 false 被当成开启。
        configuration = FastlaneCore::Configuration.create(Actions::AppStoreResourcesAction.available_options, values)
        configuration.values(ask: false).tap do |resolved|
          UI.user_error!('必须配置 App Store Connect App 的 Bundle ID') if resolved[:app_identifier].to_s.strip.empty?
          validate_build_params(resolved) if resolved[:select_build] || resolved[:submit_for_review]
        end
      rescue JSON::ParserError
        # 解析器的错误详情可能带出原始 JSON，其中可能包含认证信息。
        UI.user_error!("资源配置文件不是有效 JSON: #{config_path}")
      end

      # 复用项目的认证配置；JSON 或显式参数优先于环境变量和已有 lane 凭据。
      def self.authentication_options(params, other_action)
        return { api_key: params[:api_key] } if params[:api_key]
        return { api_key_path: params[:api_key_path] } if params[:api_key_path]
        return { username: params[:username] } if params[:username]

        path = Environment.app_store_connect_api_key_path
        unless path.empty?
          UI.user_error!("API Key JSON 不存在: #{path}") unless File.file?(path)
          return { api_key_path: File.expand_path(path) }
        end
        # 同一 lane 已创建 API Key 时直接复用，避免重复读取 P8 或改用其他凭据。
        api_key = Actions.lane_context[Actions::SharedValues::APP_STORE_CONNECT_API_KEY]
        return { api_key: api_key } if api_key

        if Environment.connect_key_id.to_s.strip.empty? || Environment.connect_issuer_id.to_s.strip.empty?
          UI.user_error!('请配置 APP_STORE_CONNECT_API_KEY_PATH 或 CONNECT_KEY_ID / CONNECT_ISSUER_ID')
        end
        { api_key: other_action.app_store_connect_api_key(
          key_id: Environment.connect_key_id,
          issuer_id: Environment.connect_issuer_id,
          key_filepath: File.expand_path(Environment.app_store_connect_p8_path),
          duration: 1200,
          in_house: false
        ) }
      end

      # 在上传 IPA 前检查目标版本并校验资源；独立调用时复用同一流程。
      def self.prepare(params)
        params = params.dup
        if metadata_required_for_new_version?(params)
          UI.message("目标 App Store 版本 #{params[:app_version]} 不存在，将上传 metadata")
          params[:metadata_changed] = true
        end
        %i[metadata screenshots].each do |kind|
          path_key = :"#{kind}_path"
          download = params[:"download_missing_#{kind}"]
          params[path_key] = resource_path(
            params[path_key], "#{kind} 目录", create: download,
            required: params[:"#{kind}_changed"] || download
          )
        end
        # 首次接入可先下载资源，再校验待上传目录；关闭的资源类别不要求目录存在。
        download_missing(params, params[:metadata_path], params[:screenshots_path])
        validate_metadata(params[:metadata_path]) if params[:metadata_changed]
        validate_screenshots(params[:screenshots_path]) if params[:screenshots_changed]
        params
      end

      # 相对路径基于 Action 执行目录解析；仅初始化下载时创建目录。
      def self.resource_path(path, label, create: false, required: true)
        UI.user_error!("#{label} 不能为空") if path.to_s.strip.empty?
        resource_path = File.expand_path(path.to_s)
        FileUtils.mkdir_p(resource_path) if create
        UI.user_error!("#{label} 不存在: #{resource_path}") if required && !File.directory?(resource_path)

        resource_path
      end

      # 递归查找各语言及 review_information 下的文本资源。
      def self.metadata_files(path)
        Dir[File.join(path, '**', METADATA_FILE_PATTERN)].select { |file| File.file?(file) }
      end

      # 仅将支持的图片扩展名计入资源，避免 README 等文件阻止首次下载。
      def self.screenshot_files(path)
        Dir[File.join(path, '**', '*')].select do |file|
          File.file?(file) && %w[.png .jpg .jpeg].include?(File.extname(file).downcase)
        end
      end

      # 上传开关开启时拒绝空目录，避免将缺失资源当成发布成功。
      def self.validate_metadata(path)
        UI.user_error!("metadata 目录为空: #{path}") if metadata_files(path).empty?
      end

      # 此处检查截图是否存在，图片格式及设备尺寸由 deliver 校验。
      def self.validate_screenshots(path)
        UI.user_error!("截图目录为空: #{path}") if screenshot_files(path).empty?
      end

      # 资源上传与 IPA、审核分开执行，防止重复上传构建或提前提交审核。
      def self.resource_options(params, metadata_path, screenshots_path)
        {
          app_identifier: params[:app_identifier],
          app_version: params[:app_version],
          metadata_path: metadata_path,
          screenshots_path: screenshots_path,
          skip_binary_upload: true,
          skip_metadata: !params[:metadata_changed],
          skip_screenshots: !params[:screenshots_changed],
          # deliver 的同步分支会绕过 skip_screenshots，必须跟随截图上传开关关闭。
          sync_screenshots: params[:screenshots_changed] && params[:sync_screenshots],
          overwrite_screenshots: params[:screenshots_changed] && params[:overwrite_screenshots],
          submit_for_review: false,
          automatic_release: false,
          run_precheck_before_submit: false,
          precheck_include_in_app_purchases: false,
          force: params[:force]
        }.tap do |options|
          options[:api_key] = params[:api_key] if params[:api_key]
          options[:api_key_path] = params[:api_key_path] if params[:api_key_path]
          options[:username] = params[:username] if params[:username]
          options[:platform] = params[:platform] if params[:platform]
          options[:release_notes] = params[:release_notes] if params[:metadata_changed] && params[:release_notes]
        end
      end

      # 在 IPA 上传前判断目标版本是否已经存在，避免新版本漏传 metadata。
      def self.metadata_required_for_new_version?(params)
        return false unless params[:upload_metadata_on_new_version] && !params[:app_version].to_s.empty?

        authenticate(params)
        app = Spaceship::ConnectAPI::App.find(params[:app_identifier])
        UI.user_error!("找不到 App Store Connect 应用: #{params[:app_identifier]}") unless app

        platform = Spaceship::ConnectAPI::Platform.map(params[:platform])
        version = app.get_edit_app_store_version(platform: platform)
        version.nil? || version.version_string != params[:app_version].to_s
      end

      # 下载只初始化 deliver 的应用和认证上下文，关闭所有上传选项。
      def self.download_options(params, metadata_path, screenshots_path)
        resource_options(params, metadata_path, screenshots_path).merge(
          skip_binary_upload: true,
          skip_metadata: true,
          skip_screenshots: true,
          sync_screenshots: false,
          overwrite_screenshots: false,
          use_live_version: params[:use_live_version]
        )
      end

      # 仅为空的资源类别下载基线，保留本地已有文案和截图。
      def self.download_missing(params, metadata_path, screenshots_path)
        download_metadata_enabled = params[:download_missing_metadata] && metadata_files(metadata_path).empty?
        download_screenshots_enabled = params[:download_missing_screenshots] && screenshot_files(screenshots_path).empty?
        return unless download_metadata_enabled || download_screenshots_enabled

        require 'deliver'
        require 'deliver/setup'
        require 'deliver/download_screenshots'

        options = FastlaneCore::Configuration.create(
          Deliver::Options.available_options,
          download_options(params, metadata_path, screenshots_path)
        )
        # 仅初始化 Runner，不调用 run，防止下载流程创建版本或触发上传。
        Deliver::Runner.new(options, skip_version: true)
        app = Deliver.cache[:app]
        platform = Spaceship::ConnectAPI::Platform.map(options[:platform])

        download_metadata(app, platform, options, metadata_path) if download_metadata_enabled
        download_screenshots(options, screenshots_path) if download_screenshots_enabled
      end

      # 最新版本与目标版本不符时使用线上版本作为文案基线，新版本可据此修改。
      def self.download_metadata(app, platform, options, metadata_path)
        version = app.get_latest_app_store_version(platform: platform)
        if options[:app_version].to_s.length > 0 && version&.version_string != options[:app_version]
          version = app.get_live_app_store_version(platform: platform)
        end
        UI.user_error!('App Store Connect 没有可下载的版本') unless version

        Deliver::Setup.new.generate_metadata_files(app, version, metadata_path, options)
      end

      # 交由 deliver 按 use_live_version 选择版本，并保留其语言与设备目录结构。
      def self.download_screenshots(options, screenshots_path)
        Deliver::DownloadScreenshots.download(options, screenshots_path)
      end

      # 仅绑定已处理成功且版本匹配的精确构建，防止同版本多个 Build 时选错包。
      def self.select_build(params)
        validate_build_params(params)
        authenticate(params)

        app = Spaceship::ConnectAPI::App.find(params[:app_identifier])
        UI.user_error!("找不到 App Store Connect 应用: #{params[:app_identifier]}") unless app

        platform = Spaceship::ConnectAPI::Platform.map(params[:platform])
        build = find_build(params, app, platform)
        valid_state = Spaceship::ConnectAPI::Build::ProcessingState::VALID
        unless build.processing_state == valid_state
          UI.user_error!(
            "App Store Build #{params[:app_version]} (#{params[:build_number]}) 处理失败，状态: #{build.processing_state}"
          )
        end

        version = app.get_edit_app_store_version(platform: platform)
        UI.user_error!("找不到可编辑的 App Store 版本: #{params[:app_version]}") unless version
        unless version.version_string == params[:app_version].to_s
          UI.user_error!(
            "可编辑版本不匹配，期望 #{params[:app_version]}，实际 #{version.version_string}"
          )
        end

        version.select_build(build_id: build.id)
        UI.success("已自动选择 App Store 构建: #{params[:app_version]} (#{params[:build_number]})")
        build
      end

      # 资源上传、构建选择成功后才使用此配置提交审核，不重复上传任何资源。
      def self.review_options(params)
        {
          app_identifier: params[:app_identifier],
          app_version: params[:app_version],
          build_number: params[:build_number].to_s,
          platform: params[:platform],
          skip_binary_upload: true,
          skip_metadata: true,
          skip_screenshots: true,
          sync_screenshots: false,
          overwrite_screenshots: false,
          submit_for_review: true,
          automatic_release: params[:automatic_release],
          run_precheck_before_submit: false,
          precheck_include_in_app_purchases: false,
          force: params[:force]
        }.tap do |options|
          options[:api_key] = params[:api_key] if params[:api_key]
          options[:api_key_path] = params[:api_key_path] if params[:api_key_path]
          options[:username] = params[:username] if params[:username]
          options[:submission_information] = params[:submission_information] if params[:submission_information]
        end
      end

      # 构建选择和审核提交必须指明版本与 Build，不允许回退到远端最新构建。
      def self.validate_build_params(params)
        UI.user_error!('自动选择构建或提交审核时必须配置 app_version') if params[:app_version].to_s.empty?
        UI.user_error!('自动选择构建或提交审核时必须配置 build_number') if params[:build_number].to_s.empty?
      end

      # 为直接调用 Spaceship 的版本查询和构建选择建立会话；优先使用 API Token。
      def self.authenticate(params)
        require 'spaceship/connect_api'

        token = Spaceship::ConnectAPI::Token.from(
          hash: params[:api_key],
          filepath: params[:api_key_path]
        )
        Spaceship::ConnectAPI.token = token if token
        return if Spaceship::ConnectAPI.token

        username = params[:username].to_s
        UI.user_error!('App Store 资源操作需要 API Key 或 username') if username.empty?

        Spaceship::ConnectAPI.login(username, nil, use_portal: false, use_tunes: true)
      end

      # 根据配置等待处理完成或只查询一次，两条路径都同时限定版本号与 Build 号。
      def self.find_build(params, app, platform)
        if params[:wait_for_build_processing]
          return wait_for_build_processing(params, app, platform, params[:build_number])
        end

        build = Spaceship::ConnectAPI::Build.all(
          app_id: app.id,
          version: params[:app_version].to_s,
          build_number: params[:build_number].to_s,
          platform: platform
        ).first
        UI.user_error!(
          "找不到 App Store Build: #{params[:app_version]} (#{params[:build_number]})"
        ) unless build
        build
      end

      # App Store Connect 偶发中断 HTTPS 连接时，在原处理超时范围内重试查询。
      def self.wait_for_build_processing(params, app, platform, build_number)
        require 'fastlane_core/build_watcher'

        timeout = params[:build_processing_timeout].to_i
        deadline = Time.now + timeout
        retry_limit = params[:build_processing_retry_limit].to_i
        retry_interval = params[:build_processing_retry_interval].to_i
        retry_count = 0

        begin
          # 网络重试共享最初的截止时间，不因重试次数增加而重新计时。
          remaining_timeout = [(deadline - Time.now).ceil, 1].max
          return FastlaneCore::BuildWatcher.wait_for_build_processing_to_be_complete(
            app_id: app.id,
            app_version: params[:app_version].to_s,
            build_version: build_number.to_s,
            platform: platform,
            poll_interval: params[:build_processing_poll_interval].to_i,
            timeout_duration: remaining_timeout,
            return_when_build_appears: false,
            return_spaceship_testflight_build: false,
            select_latest: false
          )
        rescue StandardError => error
          raise unless retryable_build_processing_error?(error)
          raise if retry_count >= retry_limit || Time.now >= deadline

          retry_count += 1
          wait_seconds = [retry_interval, [(deadline - Time.now).floor, 0].max].min
          UI.important(
            "App Store Connect 查询构建时网络异常，将在 #{wait_seconds} 秒后第 #{retry_count}/#{retry_limit} 次重试: #{error.message}"
          )
          sleep(wait_seconds) if wait_seconds.positive?
          retry
        end
      end

      # 仅重试临时连接异常，认证失败、构建无效等业务错误保持立即失败。
      def self.retryable_build_processing_error?(error)
        return true if error.is_a?(EOFError) || error.is_a?(SocketError) || error.is_a?(Timeout::Error)

        error.message.match?(
          /(SSL_connect|unexpected eof|connection (?:reset|aborted|failed)|execution expired|timed out|read timeout|socket error)/i
        )
      end

      private_class_method :download_metadata, :download_screenshots, :authenticate, :find_build,
                           :wait_for_build_processing, :retryable_build_processing_error?
    end
  end
end
