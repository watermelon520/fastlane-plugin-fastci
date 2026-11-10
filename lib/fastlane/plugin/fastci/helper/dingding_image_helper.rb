require 'base64'
require 'json'
require 'open3'
require 'tempfile'
require 'uri'
require 'fastlane_core/ui/ui'

module Fastlane
  module Helper
    # 二维码在构建机下载后内嵌到 Markdown，避免钉钉客户端再次访问分发服务器。
    class DingdingImageHelper
      # Base64 会增加约三分之一体积，为通知正文和更新说明留出空间。
      MAX_IMAGE_BYTES = 8 * 1024

      def self.base64_source(url)
        uri = URI.parse(url.to_s)
        return unless %w[http https].include?(uri.scheme) && uri.host && !uri.userinfo

        data = download_image(uri)
        return unless data

        mime_type = image_mime_type(data)
        unless mime_type
          UI.important('二维码响应不是 PNG、JPEG 或 GIF 图片，通知保留图片链接')
          return nil
        end

        "data:#{mime_type};base64,#{Base64.strict_encode64(data)}"
      rescue StandardError => error
        # 不输出 URL、响应正文或异常原文，避免签名参数进入打包日志。
        UI.important("二维码内嵌失败（#{error.class}），通知保留图片链接")
        nil
      end

      def self.download_image(uri)
        Tempfile.create(['fastci-dingding-qr', '.image']) do |file|
          # 不经过 shell；图片地址仅通过 stdin 传递，保留证书校验并限制下载量与耗时。
          _output, _stderr, status = Open3.capture3(
            '/usr/bin/curl', '--disable', '--silent', '--show-error', '--fail',
            '--location', '--max-redirs', '3', '--proto', '=http,https', '--proto-redir', '=http,https',
            '--connect-timeout', '5', '--max-time', '15', '--max-filesize', MAX_IMAGE_BYTES.to_s,
            '--output', file.path, '--config', '-', stdin_data: "url = #{JSON.generate(uri.to_s)}\n"
          )
          unless status.success?
            UI.important("二维码下载失败（curl exit=#{status.exitstatus}），通知保留图片链接")
            return nil
          end

          # 额外检查实际字节数，兼容未返回 Content-Length 的图片接口。
          data = File.binread(file.path, MAX_IMAGE_BYTES + 1)
          if data.empty? || data.bytesize > MAX_IMAGE_BYTES
            UI.important('二维码为空或超过 8 KB，通知保留图片链接')
            return nil
          end

          data
        end
      end

      # 按文件签名识别格式，避免把登录页或错误 HTML 当作图片编码发送。
      def self.image_mime_type(data)
        return 'image/png' if data.start_with?("\x89PNG\r\n\x1a\n".b)
        return 'image/jpeg' if data.start_with?("\xff\xd8\xff".b)
        return 'image/gif' if data.start_with?('GIF87a', 'GIF89a')
      end

      private_class_method :download_image, :image_mime_type
    end
  end
end
