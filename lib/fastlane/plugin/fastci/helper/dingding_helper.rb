require 'fastlane_core/ui/ui'
require 'fileutils'

module Fastlane
  module Helper
    class DingdingHelper

      def self.sendMarkdown(text)
        UI.message("*************| 开始钉钉消息通知 |*************")

        curl = %Q{
          curl 'https://oapi.dingtalk.com/robot/send?access_token=#{Environment.dingdingToken}' \
          -H 'Content-Type:application/json' \
          -d '{
            "msgtype":"markdown",
            "markdown":{
              "title":"#{Environment.scheme} 打包通知",
              "text":"#{text}"
            }
          }'
        }
        system curl
      end

    end
  end
end
