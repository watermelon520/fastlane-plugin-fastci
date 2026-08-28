require 'fileutils'
require 'json'
require 'timeout'

module Fastlane
  module Helper
    # App Store Connect 资源发布辅助方法
    class AppStoreResourcesHelper
      METADATA_FILE_PATTERN = '*.txt'

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
        force
      ].freeze

      DEFAULT_PARAMS = {
        metadata_path: 'fastlane/metadata',
        screenshots_path: 'fastlane/screenshots',
        metadata_changed: true,
        screenshots_changed: true,
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

      TESTFLIGHT_CONFIG_KEYS = %i[
        app_identifier
        app_version
        testflight_build_number
        changelog
        api_key
        api_key_path
        username
        platform
        wait_for_build_processing
        build_processing_timeout
        build_processing_poll_interval
        build_processing_retry_limit
        build_processing_retry_interval
        distribute_external
        notify_external_testers
        submit_beta_review
        groups
      ].freeze

      TESTFLIGHT_DEFAULT_PARAMS = {
        platform: 'ios',
        wait_for_build_processing: true,
        build_processing_timeout: 3600,
        build_processing_poll_interval: 30,
        build_processing_retry_limit: 3,
        build_processing_retry_interval: 15,
        distribute_external: false,
        notify_external_testers: false,
        submit_beta_review: true
      }.freeze

      def self.load_params(params)
        config_path = params[:config_path]
        return params if config_path.to_s.empty?

        config_path = File.expand_path(config_path.to_s)
        UI.user_error!("资源配置文件不存在: #{config_path}") unless File.file?(config_path)

        config = JSON.parse(File.read(config_path))
        UI.user_error!("资源配置文件必须是 JSON 对象: #{config_path}") unless config.is_a?(Hash)

        config = config.each_with_object({}) do |(key, value), values|
          symbol_key = key.to_sym
          UI.user_error!("资源配置包含不支持的字段: #{key}") unless CONFIG_KEYS.include?(symbol_key)
          values[symbol_key] = value
        end

        explicit_values = if params.respond_to?(:_values)
                            params._values
                          else
                            params
                          end
        explicit_values = explicit_values.reject { |key, value| value.nil? }
        DEFAULT_PARAMS.merge(config).merge(explicit_values).merge(config_path: config_path)
      rescue JSON::ParserError => e
        UI.user_error!("资源配置文件不是有效 JSON: #{e.message}")
      end

      def self.resource_path(path, label, create: false, required: true)
        resource_path = File.expand_path(path.to_s)
        FileUtils.mkdir_p(resource_path) if create
        UI.user_error!("#{label} 不存在: #{resource_path}") if required && !File.directory?(resource_path)

        resource_path
      end

      def self.load_testflight_params(params)
        config_path = params[:testflight_config_path]
        config = {}
        unless config_path.to_s.empty?
          config_path = File.expand_path(config_path.to_s)
          UI.user_error!("TestFlight 配置文件不存在: #{config_path}") unless File.file?(config_path)

          config = JSON.parse(File.read(config_path))
          UI.user_error!("TestFlight 配置文件必须是 JSON 对象: #{config_path}") unless config.is_a?(Hash)

          config = config.each_with_object({}) do |(key, value), values|
            symbol_key = key.to_sym
            UI.user_error!("TestFlight 配置包含不支持的字段: #{key}") unless TESTFLIGHT_CONFIG_KEYS.include?(symbol_key)
            values[symbol_key] = value
          end
        end

        explicit_values = if params.respond_to?(:_values)
                            params._values
                          else
                            params
                          end
        explicit_values = explicit_values.each_with_object({}) do |(key, value), values|
          values[key] = value if TESTFLIGHT_CONFIG_KEYS.include?(key) && !value.nil?
        end

        explicit_values[:changelog] = params[:testflight_changelog] if params[:testflight_changelog]
        explicit_values[:distribute_external] = params[:testflight_distribute_external] unless params[:testflight_distribute_external].nil?
        explicit_values[:notify_external_testers] = params[:testflight_notify_external_testers] unless params[:testflight_notify_external_testers].nil?
        explicit_values[:submit_beta_review] = params[:testflight_submit_beta_review] unless params[:testflight_submit_beta_review].nil?
        explicit_values[:groups] = params[:testflight_groups] if params[:testflight_groups]

        TESTFLIGHT_DEFAULT_PARAMS.merge(config).merge(explicit_values).tap do |values|
          values[:testflight_config_path] = config_path unless config_path.to_s.empty?
        end
      rescue JSON::ParserError => e
        UI.user_error!("TestFlight 配置文件不是有效 JSON: #{e.message}")
      end

      def self.metadata_files(path)
        Dir[File.join(path, '**', METADATA_FILE_PATTERN)].select { |file| File.file?(file) }
      end

      def self.screenshot_files(path)
        Dir[File.join(path, '**', '*')].select do |file|
          File.file?(file) && %w[.png .jpg .jpeg].include?(File.extname(file).downcase)
        end
      end

      def self.validate_metadata(path)
        UI.user_error!("metadata 目录为空: #{path}") if metadata_files(path).empty?
      end

      def self.validate_screenshots(path)
        UI.user_error!("截图目录为空: #{path}") if screenshot_files(path).empty?
      end

      def self.resource_options(params, metadata_path, screenshots_path)
        {
          app_identifier: params[:app_identifier],
          app_version: params[:app_version],
          metadata_path: metadata_path,
          screenshots_path: screenshots_path,
          skip_binary_upload: true,
          skip_metadata: !params[:metadata_changed],
          skip_screenshots: !params[:screenshots_changed],
          sync_screenshots: params[:sync_screenshots],
          overwrite_screenshots: params[:overwrite_screenshots],
          submit_for_review: false,
          run_precheck_before_submit: false,
          force: params[:force]
        }.tap do |options|
          options[:api_key] = params[:api_key] if params[:api_key]
          options[:api_key_path] = params[:api_key_path] if params[:api_key_path]
          options[:username] = params[:username] if params[:username]
          options[:platform] = params[:platform] if params[:platform]
        end
      end

      # 在 IPA 上传前判断目标版本是否已经存在，避免新版本漏传 metadata。
      def self.metadata_required_for_new_version?(params)
        return false unless params[:upload_metadata_on_new_version]

        authenticate(params)
        app = Spaceship::ConnectAPI::App.find(params[:app_identifier])
        UI.user_error!("找不到 App Store Connect 应用: #{params[:app_identifier]}") unless app

        platform = Spaceship::ConnectAPI::Platform.map(params[:platform])
        version = app.get_edit_app_store_version(platform: platform)
        version.nil? || version.version_string != params[:app_version].to_s
      end

      def self.download_options(params, metadata_path, screenshots_path)
        resource_options(params, metadata_path, screenshots_path).merge(
          skip_binary_upload: true,
          skip_metadata: true,
          skip_screenshots: true,
          use_live_version: params[:use_live_version]
        )
      end

      def self.download_missing(params, metadata_path, screenshots_path)
        download_metadata_enabled = params[:download_missing_metadata] && metadata_files(metadata_path).empty?
        download_screenshots_enabled = params[:download_missing_screenshots] && screenshot_files(screenshots_path).empty?
        return unless download_metadata_enabled || download_screenshots_enabled

        require 'deliver'
        require 'deliver/setup'
        require 'deliver/download_screenshots'

        options = download_options(params, metadata_path, screenshots_path)
        Deliver::Runner.new(options, skip_version: true)
        app = Deliver.cache[:app]
        platform = Spaceship::ConnectAPI::Platform.map(options[:platform])

        download_metadata(app, platform, options, metadata_path) if download_metadata_enabled
        download_screenshots(options, screenshots_path) if download_screenshots_enabled
      end

      def self.download_metadata(app, platform, options, metadata_path)
        version = app.get_latest_app_store_version(platform: platform)
        if options[:app_version].to_s.length > 0 && version&.version_string != options[:app_version]
          version = app.get_live_app_store_version(platform: platform)
        end
        UI.user_error!('App Store Connect 没有可下载的版本') unless version

        Deliver::Setup.new.generate_metadata_files(app, version, metadata_path, options)
      end

      def self.download_screenshots(options, screenshots_path)
        Deliver::DownloadScreenshots.download(options, screenshots_path)
      end

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

      # TestFlight 不需要绑定到 App Store 版本，这里只确认本次上传的精确构建已处理完成。
      def self.verify_testflight_build(params)
        validate_testflight_build_params(params)
        authenticate(params)

        app = Spaceship::ConnectAPI::App.find(params[:app_identifier])
        UI.user_error!("找不到 App Store Connect 应用: #{params[:app_identifier]}") unless app

        platform = Spaceship::ConnectAPI::Platform.map(params[:platform])
        build = find_testflight_build(params, app, platform)
        valid_state = Spaceship::ConnectAPI::Build::ProcessingState::VALID
        unless build.processing_state == valid_state
          UI.user_error!(
            "TestFlight Build #{params[:app_version]} (#{params[:testflight_build_number]}) 处理失败，状态: #{build.processing_state}"
          )
        end

        UI.success(
          "已确认 TestFlight 构建: #{params[:app_version]} (#{params[:testflight_build_number]})"
        )
        build
      end

      def self.review_options(params)
        {
          app_identifier: params[:app_identifier],
          app_version: params[:app_version],
          build_number: params[:build_number].to_s,
          platform: params[:platform],
          skip_binary_upload: true,
          skip_metadata: true,
          skip_screenshots: true,
          submit_for_review: true,
          automatic_release: params[:automatic_release],
          run_precheck_before_submit: false,
          force: params[:force]
        }.tap do |options|
          options[:api_key] = params[:api_key] if params[:api_key]
          options[:api_key_path] = params[:api_key_path] if params[:api_key_path]
          options[:username] = params[:username] if params[:username]
          options[:submission_information] = params[:submission_information] if params[:submission_information]
        end
      end

      def self.validate_build_params(params)
        UI.user_error!('自动选择构建或提交审核时必须配置 app_version') if params[:app_version].to_s.empty?
        UI.user_error!('自动选择构建或提交审核时必须配置 build_number') if params[:build_number].to_s.empty?
      end

      def self.validate_testflight_build_params(params)
        UI.user_error!('TestFlight 构建校验需要配置 app_version') if params[:app_version].to_s.empty?
        UI.user_error!('TestFlight 构建校验需要配置 testflight_build_number') if params[:testflight_build_number].to_s.empty?
      end

      def self.authenticate(params)
        require 'spaceship/connect_api'

        token = Spaceship::ConnectAPI::Token.from(
          hash: params[:api_key],
          filepath: params[:api_key_path]
        )
        Spaceship::ConnectAPI.token = token if token
        return if Spaceship::ConnectAPI.token

        username = params[:username].to_s
        UI.user_error!('自动选择构建需要 API Key 或 username') if username.empty?

        Spaceship::ConnectAPI.login(username, nil, use_portal: false, use_tunes: true)
      end

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

      def self.find_testflight_build(params, app, platform)
        if params[:wait_for_build_processing]
          return wait_for_build_processing(params, app, platform, params[:testflight_build_number])
        end

        build = Spaceship::ConnectAPI::Build.all(
          app_id: app.id,
          version: params[:app_version].to_s,
          build_number: params[:testflight_build_number].to_s,
          platform: platform
        ).first
        UI.user_error!(
          "找不到 TestFlight Build: #{params[:app_version]} (#{params[:testflight_build_number]})"
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

      def self.retryable_build_processing_error?(error)
        return true if error.is_a?(EOFError) || error.is_a?(SocketError) || error.is_a?(Timeout::Error)

        error.message.match?(
          /(SSL_connect|unexpected eof|connection (?:reset|aborted|failed)|execution expired|timed out|read timeout|socket error)/i
        )
      end

      private_class_method :download_metadata, :download_screenshots, :authenticate, :find_build, :find_testflight_build,
                           :wait_for_build_processing, :retryable_build_processing_error?
    end
  end
end
