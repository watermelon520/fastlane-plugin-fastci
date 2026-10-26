require 'fastlane/plugin/fastci/helper/fastci_zealot_helper'

module Fastlane
  module Actions
    # 手动同步 Apple 开发者账号中的 iOS 设备，不挂入自动打包流程。
    class SyncZealotDevicesAction < ZealotSyncDevicesAction
      extend Fastlane::Helper::FastciZealotHelper

      def self.run(params)
        validate_zealot_connection!(zealot_parameters(params))
        Actions.lane_context.delete(SharedValues::ZEAALOT_ERROR_MESSAGE)
        devices = fetch_ios_devices(params)
        print_table(build_table_data(params, devices), title: 'sync_zealot_devices')

        # 沿用官方的设备上传协议，按实际 HTTP 结果统计，避免失败被计为成功。
        failed = devices.count { |device| !sync_ios_device(params, device) }
        result = { total: devices.size, succeeded: devices.size - failed, failed: failed }
        UI.message("Zealot iOS 设备同步：成功 #{result[:succeeded]}，失败 #{failed}")
        result
      end

      def self.fetch_ios_devices(params)
        require 'spaceship'

        token = Spaceship::ConnectAPI::Token.from(hash: params[:api_key], filepath: params[:api_key_path])
        if token
          Spaceship::ConnectAPI.token = token
          return Spaceship::ConnectAPI::Device.all(filter: { platform: 'IOS' })
        end

        credentials = CredentialsManager::AccountManager.new(user: params[:username])
        Spaceship.login(credentials.user, credentials.password)
        Spaceship.select_team
        Spaceship::Device.all(mac: false)
      end
      private_class_method :fetch_ios_devices

      def self.sync_ios_device(params, device)
        response = sync_deivce(params, device)
        return true if response.success?

        show_error("Zealot 设备同步失败（HTTP #{response.status}）", params[:fail_on_error])
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => error
        show_error("Zealot 设备同步请求失败：#{error.class}", params[:fail_on_error])
      end
      private_class_method :sync_ios_device

      def self.available_options
        zealot_options(ZealotSyncDevicesAction, excluding: [:platform])
      end

      def self.description
        '同步 Apple 开发者账号中的 iOS 设备到 Zealot'
      end

      def self.example_code
        ['sync_zealot_devices(api_key_path: "./app_store_connect_api_key.json")']
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
