require 'fastlane/action'
include Fastlane::Helper

module Fastlane
  module Actions
    # 钉钉通知
    class NotiDingdingAction < Action
      def self.run(params)
        UI.message("*************| 开始钉钉消息通知 |*************")
        notiText = params[:notiText] || ""

        curl = %Q{
          curl 'https://oapi.dingtalk.com/robot/send?access_token=#{Environment.dingdingToken}' \
          -H 'Content-Type:application/json' \
          -d '{
            "msgtype":"markdown",
            "markdown":{
              "title":"#{Environment.scheme} 打包通知",
              "text":"#{notiText}"
            }
          }'
        }
        system curl
      end

      def self.description
        "钉钉通知"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :notiText,
            description: "要发送的钉钉通知内容",
            optional: false, # 是否可选
            type: String
          ),
        ]
      end

      def self.is_supported?(platform)
        platform == :ios
      end

      def self.category
        :notifications
      end

    end
  end
end