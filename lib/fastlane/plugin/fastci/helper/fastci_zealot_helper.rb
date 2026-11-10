require 'fastlane/plugin/zealot'

module Fastlane
  module Helper
    # 复用官方 Action 的协议与参数，仅收口 FastCI 的 iOS 边界和日志脱敏。
    module FastciZealotHelper
      def zealot_options(action, excluding: [])
        options = action.available_options.reject do |option|
          excluding.include?(option.key) || option.key == :fail_on_error
        end

        # 新增上传渠道默认明确报错，避免 CI 把失败当作上传完成。
        options << FastlaneCore::ConfigItem.new(
          key: :fail_on_error,
          env_name: 'ZEALOT_FAIL_ON_ERROR',
          description: 'Zealot 请求失败时终止当前任务',
          optional: true,
          default_value: true,
          type: Boolean
        )
        options
      end

      def zealot_parameters(params)
        params.all_keys.each_with_object({}) do |key, values|
          value = params[key]
          values[key] = value unless value.nil?
        end
      end

      def validate_zealot_connection!(values)
        keys = [:endpoint, :token]
        keys << :channel_key if values.key?(:channel_key)
        keys.each do |key|
          UI.user_error!("缺少 Zealot #{key}") if values[key].to_s.strip.empty?
        end
      end

      # 官方部分 Action 未隐藏 token；只改变当前封装的输出，不修改上游全局实现。
      def print_table(form, title: 'zealot', hidden_keys: [], remove_empty_value: true)
        super(
          form,
          title: title,
          hidden_keys: hidden_keys + [:token, :Token],
          remove_empty_value: remove_empty_value
        )
      end

    end
  end
end
