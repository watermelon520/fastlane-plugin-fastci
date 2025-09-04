require 'fastlane/action'
include Fastlane::Helper

module Fastlane
  module Actions
    # 更新 build 号
    class UpdateBuildNumberAction < Action
      def self.run(params)
        currentTime = Time.new.strftime("%Y%m%d")
        build = CommonHelper.get_cached_build_number

        if build.include?("#{currentTime}.")
          # 当天版本 计算迭代版本号
          lastStr = build.split('.').last
          lastNum = lastStr.to_i
          lastNum += 1
          lastStr = lastNum.to_s.rjust(2, '0')
          build = "#{currentTime}.#{lastStr}"
        else
          # 非当天版本 build 重置
          build = "#{currentTime}.01"
        end

        UI.message("*************| 更新 build #{build} |*************")
        # 更改项目 build 号
        Actions::IncrementBuildNumberAction.run(
          build_number: build
        )

        # 缓存新的 build 号
        CommonHelper.write_cached_txt(Constants.BUILD_NUMBER_FILE, build)
      end

      def self.description
        "更新 build 号"
      end

      def self.available_options
        []
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