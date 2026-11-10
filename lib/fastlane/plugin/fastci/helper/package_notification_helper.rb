require 'cgi'
require 'uri'
require 'fastlane/plugin/fastci/helper/dingding_helper'
require 'fastlane/plugin/fastci/helper/dingding_image_helper'

module Fastlane
  module Helper
    # 每次 package 独立保存通知上下文，避免多个 lane 之间串用版本或分发结果。
    class PackageNotificationHelper
      PLATFORM_NAMES = {
        local: '本地构建', pgy: '蒲公英', fir: 'fir', zealot: 'Zealot',
        testflight: 'TestFlight', app_store: 'App Store', checks: '代码检查', sentry: 'Sentry'
      }.freeze

      def initialize(params)
        @enabled = params[:is_notice_dingding] != false
        @scheme = params[:scheme] || Environment.scheme
        @export_method = params[:export_method] || 'development'
        @configuration = %w[app-store testFlight].include?(@export_method) ? 'Release' : (params[:configuration] || 'Debug')
        @version, @build = params[:version], params[:build]
        @changelog = params[:changelog]
        @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        stage(:local, '准备构建')
      end

      # 在构建前记录实际版本，失败通知也能定位到本次产物。
      def build_info(version:, build:)
        @version, @build = version, build
      end

      def stage(platform, name)
        @platform, @stage = platform, name
      end

      # 各渠道只转换自己的返回字段，公共标题与正文始终使用同一模板。
      def distribution_completed(platform, result = {}, store_result: {})
        stage(platform, '上传分发包')
        if !result.is_a?(Hash) || result.empty?
          return notify('上传未完成', details: { '说明' => '上传接口未返回成功结果，请查看构建日志。' }, failed: true)
        end

        fields = distribution_fields(platform, result, store_result)
        notify('上传完成', **fields)
      end

      def store_skipped(platform)
        stage(platform, '上传分发包')
        notify('未上传', details: { '说明' => 'IPA 已生成，未配置商店上传认证。' })
      end

      def checks_completed(names)
        return if names.empty?

        stage(:checks, '代码检查')
        notify('检查执行完成', details: {
          '已执行' => names.join('、'), '说明' => '检查已执行，发现的问题请查看本次生成的报告。'
        })
      end

      # 失败消息只说明阶段，不把可能含凭据、个人路径的原始异常发送到群里。
      def failure(store_result: {})
        details = { '失败阶段' => @stage, '说明' => '本次流程已中断，请查看构建日志。' }
        if [:testflight, :app_store].include?(@platform) && !store_result.empty?
          details['失败阶段'] = store_result[:stage]
          details['IPA'] = store_result[:ipa_uploaded] ? '已上传' : '尚未确认上传完成'
        end
        notify('执行失败', details: details, failed: true)
      end

      private

      def distribution_fields(platform, result, store_result)
        case platform
        when :pgy
          {
            links: { '安装页面' => value(result, :fastlaneAddedWholeVisitUrl) },
            qr_code: value(result, :buildQRCodeURL), password: Environment.pgy_password
          }
        when :fir
          { links: { '安装页面' => value(result, :download_url) }, password: Environment.fir_password }
        when :zealot
          {
            links: { '版本详情' => value(result, :release_url), '安装页面' => value(result, :install_url) },
            qr_code: value(result, :qrcode_url),
            details: { 'Release ID' => value(result, :release_id), 'dSYM' => value(result, :dsym_status) || '未开启' }
          }
        when :testflight
          {
            links: store_links.merge('TestFlight 测试邀请' => Environment.dingding_testflight_url),
            details: { '说明' => 'IPA 已上传，尚未等待 Apple 处理完成；测试可用性请在 App Store Connect 确认。' }
          }
        when :app_store
          { links: store_links.merge('App Store 线上页面' => Environment.dingding_app_store_url), details: store_details(store_result) }
        else
          {}
        end
      end

      def store_links
        { 'App Store Connect' => 'https://appstoreconnect.apple.com/apps' }
      end

      # 使用上传流程确认过的结果，不从配置推断资源已上传或审核已通过。
      def store_details(result)
        details = { '说明' => '上传完成不代表审核通过或已上线；线上页面可能仍为旧版本。' }
        unless result[:resources_enabled]
          return details.merge('商店资源' => '未开启，仅上传 IPA')
        end

        details.merge(
          '元数据' => result[:metadata_uploaded] ? '已上传' : '未上传',
          '截图' => result[:screenshots_uploaded] ? '已上传' : '未上传',
          '构建选择' => result[:build_selected] ? '已选择本次 Build' : '未执行',
          '提交审核' => result[:review_submitted] ? '已提交' : '未提交'
        )
      end

      def value(result, key)
        result[key] || result[key.to_s]
      end

      # 不写空链接、空密码；安装密码开关默认保留旧版的展示行为。
      def notify(status, details: {}, links: {}, qr_code: nil, password: nil, failed: false)
        return unless @enabled && !Environment.dingdingToken.to_s.strip.empty?

        platform = PLATFORM_NAMES.fetch(@platform)
        title = "#{@scheme} iOS · #{platform} · #{status}"
        fields = {
          '应用' => @scheme, 'Bundle ID' => Environment.bundleID, '分发平台' => platform,
          '状态' => status, '版本' => @version, 'Build' => @build,
          '打包方式' => @export_method, '构建配置' => @configuration
        }.merge(details)
        if Environment.dingding_include_install_password
          fields['安装密码'] = password
        end
        fields['累计耗时'] = "#{(Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at).round} 秒"
        fields['通知时间'] = Time.now.strftime('%Y-%m-%d %H:%M:%S %:z')
        sections = ["### #{failed ? '❌' : '📦'} #{markdown(title)}"]
        sections << fields.map { |key, val| "- **#{key}**：#{markdown(val)}" unless val.to_s.strip.empty? }.compact.join("\n")
        sections.concat(link_sections(links, qr_code))
        unless @changelog.to_s.strip.empty?
          # 为长更新日志留出消息空间；截断的是展示文案，不影响平台上传内容。
          notes = @changelog.to_s[0, 1000]
          notes += '…（更新说明已截断）' if @changelog.to_s.length > 1000
          # 普通换行会被 Markdown 合并成段落；两个行尾空格明确要求换行。
          # 仅格式化通知展示，兼容 CRLF，平台上传继续使用原始 changelog。
          formatted_notes = markdown(notes).gsub(/\r\n?/, "\n").gsub("\n", "  \n")
          sections << "**更新说明**\n\n#{formatted_notes}"
        end
        DingdingHelper.sendMarkdown(sections.join("\n\n"), title: title)
      end

      def link_sections(links, qr_code)
        sections = links.map do |label, url|
          safe = web_url(url)
          "[#{label}](#{safe})" if safe
        end.compact
        qr_url = web_url(qr_code)
        if qr_url
          image_source = DingdingImageHelper.base64_source(qr_url)
          sections << "**扫码安装**\n\n![安装二维码](#{image_source})" if image_source
          sections << "[打开二维码](#{qr_url})"
        end
        sections
      end

      # 仅允许普通网页地址，避免返回值中的括号或凭据破坏 Markdown 链接。
      def web_url(value)
        url = value.to_s.strip
        uri = URI.parse(url)
        return unless %w[https http].include?(uri.scheme) && uri.host && !uri.userinfo
        return if url.match?(/[\s<>]/)

        url.gsub('(', '%28').gsub(')', '%29')
      rescue URI::InvalidURIError
        nil
      end

      def markdown(value)
        CGI.escapeHTML(value.to_s).gsub(/[\\`*_\[\]#]/) { |char| "\\#{char}" }
      end
    end
  end
end
