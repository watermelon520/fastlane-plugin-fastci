require 'fastlane_core/ui/ui'
require 'json'
require 'open3'
require 'uri'

module Fastlane
  module Helper
    class DingdingHelper

      # 保留原调用入口；JSON 序列化避免更新说明中的引号、换行破坏消息。
      def self.sendMarkdown(text, title: nil)
        token = Environment.dingdingToken.to_s.strip
        if token.empty?
          UI.message('跳过钉钉通知：未配置 DINGDING_TOKEN')
          return false
        end

        payload = {
          msgtype: 'markdown',
          markdown: { title: title || "#{Environment.scheme} 打包通知", text: text }
        }
        UI.message('开始发送钉钉通知')
        response = post_message(token, payload)
        return false unless response

        unless response[:code].between?(200, 299)
          UI.important("钉钉通知发送失败（HTTP #{response[:code]}），继续原流程")
          return false
        end

        result = JSON.parse(response[:body])
        if result.is_a?(Hash) && result['errcode'] == 0
          UI.success('钉钉通知发送成功')
          return true
        end

        # 不输出响应原文或异常消息，避免机器人 Token 随请求地址进入日志。
        error_code = result.is_a?(Hash) && result['errcode'].is_a?(Integer) ? result['errcode'] : '未知'
        UI.important("钉钉拒绝消息（errcode=#{error_code}），请检查机器人配置；继续原流程")
        false
      rescue StandardError => error
        UI.important("钉钉通知发送失败（#{error.class}），请检查网络及机器人配置；继续原流程")
        false
      end

      # 使用系统 curl 的证书链校验，避开 Ruby OpenSSL 在本机的 CRL 校验错误。
      # URL 和 JSON 通过 stdin 配置传递，不进入进程参数或 shell；保持 TLS 校验与超时。
      def self.post_message(token, payload)
        uri = URI('https://oapi.dingtalk.com/robot/send')
        uri.query = URI.encode_www_form(access_token: token)
        # 第二次 JSON 编码只为 curl 配置中的双引号和反斜杠转义，正文仍为原始 JSON。
        configuration = "url = #{JSON.generate(uri.to_s)}\ndata-binary = #{JSON.generate(JSON.generate(payload))}\n"
        output, _stderr, status = Open3.capture3(
          '/usr/bin/curl', '--disable', '--silent', '--show-error',
          '--connect-timeout', '5', '--max-time', '15',
          '--header', 'Content-Type: application/json; charset=utf-8',
          '--write-out', "\n%{http_code}", '--config', '-', stdin_data: configuration
        )
        unless status.success?
          UI.important("钉钉通知网络请求失败（curl exit=#{status.exitstatus}），继续原流程")
          return nil
        end

        body, _separator, code = output.rpartition("\n")
        { code: Integer(code, 10), body: body }
      end
      private_class_method :post_message
    end
  end
end
