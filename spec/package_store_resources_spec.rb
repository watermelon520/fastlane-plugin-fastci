require 'spec_helper'

describe Fastlane::Actions::PackageAction do
  let(:environment) { Fastlane::Helper::Environment }
  let(:other_actions) { double('other actions') }
  let(:options) do
    {
      export_method: 'app-store', is_notice_dingding: false,
      app_store_resources_enabled: true, app_store_resources_config_path: '/example/resources.json'
    }
  end

  before do
    allow(described_class).to receive(:other_action).and_return(other_actions)
    allow(environment).to receive_messages(
      is_auto_update_provisioning: true, scheme: 'Example', bundleID: 'com.example.app',
      project: nil, workspace: 'Example.xcworkspace', extension_bundle_ids: [],
      connect_key_id: nil, connect_issuer_id: nil, app_store_connect_api_key_path: '',
      sentry_auth_token: nil, pgy_api_key: nil, fir_api_token: nil, zealot_token: nil
    )
    allow(other_actions).to receive(:update_build_number)
    allow(other_actions).to receive(:get_version_number).and_return('1.2.3')
    allow(other_actions).to receive(:get_build_number).and_return('42')
    allow(other_actions).to receive(:gym)
    # 此测试只验证参数串接，隔离打包和本地文件操作。
    allow(FileUtils).to receive(:rm_rf)
    allow(FileUtils).to receive(:mkdir_p)
    allow(FileUtils).to receive(:cp_r)
  end

  it 'passes the actual bundle, version and build into configured store uploads' do
    expect(other_actions).to receive(:upload_store).with(
      { release_notes: '', isTestFlight: false, app_store_resources_enabled: true,
        app_store_resources_config_path: '/example/resources.json',
        app_identifier: 'com.example.app', app_version: '1.2.3', build_number: '42' }
    )
    described_class.run(options)
  end

  it 'explicitly disables resources in the upload call when not enabled' do
    allow(environment).to receive(:connect_key_id).and_return('key-id')
    allow(environment).to receive(:connect_issuer_id).and_return('issuer-id')
    expect(other_actions).to receive(:upload_store).with({
      release_notes: '', isTestFlight: false, app_store_resources_enabled: false
    })
    described_class.run(options.merge(app_store_resources_enabled: nil, app_store_resources_config_path: nil))
  end

  it 'does not start store uploads solely because a resource path exists' do
    expect(other_actions).not_to receive(:upload_store)
    described_class.run(options.merge(app_store_resources_enabled: nil))
  end

  it 'forwards an explicit false without passing the resource path' do
    allow(environment).to receive(:app_store_connect_api_key_path).and_return('/secure/key.json')
    expect(other_actions).to receive(:upload_store).with({
      release_notes: '', isTestFlight: false, app_store_resources_enabled: false
    })
    described_class.run(options.merge(app_store_resources_enabled: false))
  end

  it 'fails before building when resources are enabled without a config path' do
    expect(other_actions).not_to receive(:gym)
    expect(other_actions).not_to receive(:update_build_number)
    expect { described_class.run(options.merge(app_store_resources_config_path: nil)) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /APP_STORE_RESOURCES_CONFIG_PATH/)
  end

  it 'does not forward App Store resource configuration to TestFlight' do
    allow(environment).to receive(:app_store_connect_api_key_path).and_return('/secure/key.json')
    expect(other_actions).to receive(:upload_store).with({
      release_notes: '', isTestFlight: true, app_store_resources_enabled: false
    })
    described_class.run(options.merge(export_method: 'testFlight'))
  end

  it 'does not run store uploads for development builds' do
    expect(other_actions).not_to receive(:upload_store)
    described_class.run(options.merge(export_method: 'development'))
  end

  it 'reads the same environment configuration in all three entry points' do
    previous = ENV['APP_STORE_RESOURCES_CONFIG_PATH']
    ENV['APP_STORE_RESOURCES_CONFIG_PATH'] = '/example/resources.json'
    [described_class, Fastlane::Actions::UploadStoreAction].each do |action|
      params = FastlaneCore::Configuration.create(action.available_options, {})
      expect(params[:app_store_resources_config_path]).to eq('/example/resources.json')
    end
    option = Fastlane::Actions::AppStoreResourcesAction.available_options.find { |item| item.key == :config_path }
    expect(option.env_name).to eq('APP_STORE_RESOURCES_CONFIG_PATH')
  ensure
    ENV['APP_STORE_RESOURCES_CONFIG_PATH'] = previous
  end

  it 'defaults all resource master switches to false and lets explicit false override the environment' do
    previous = ENV['APP_STORE_RESOURCES_ENABLED']
    actions = [described_class, Fastlane::Actions::UploadStoreAction, Fastlane::Actions::AppStoreResourcesAction]
    ENV.delete('APP_STORE_RESOURCES_ENABLED')
    actions.each do |action|
      expect(FastlaneCore::Configuration.create(action.available_options, {})[:app_store_resources_enabled]).to be(false)
    end
    ENV['APP_STORE_RESOURCES_ENABLED'] = 'false'
    actions.each do |action|
      expect(FastlaneCore::Configuration.create(action.available_options, {})[:app_store_resources_enabled]).to be(false)
    end
    ENV['APP_STORE_RESOURCES_ENABLED'] = 'true'
    actions.each do |action|
      expect(FastlaneCore::Configuration.create(action.available_options, {})[:app_store_resources_enabled]).to be(true)
      params = FastlaneCore::Configuration.create(action.available_options, app_store_resources_enabled: false)
      expect(params[:app_store_resources_enabled]).to be(false)
    end
  ensure
    ENV['APP_STORE_RESOURCES_ENABLED'] = previous
  end
end
