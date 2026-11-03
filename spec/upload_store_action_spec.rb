require 'spec_helper'
require 'tmpdir'
require 'deliver'

describe Fastlane::Actions::UploadStoreAction do
  let(:environment) { Fastlane::Helper::Environment }
  let(:helper) { Fastlane::Helper::AppStoreResourcesHelper }
  let(:other_actions) { double('other actions') }
  let(:api_key) { { key_id: 'test', key: 'test' } }
  let(:root) { Dir.mktmpdir('fastci-upload-spec') }
  let(:config_path) { File.join(root, 'resources.json') }

  before do
    allow(described_class).to receive(:other_action).and_return(other_actions)
    allow(environment).to receive(:app_store_connect_api_key_path).and_return('')
    allow(environment).to receive(:connect_key_id).and_return('test-id')
    allow(environment).to receive(:connect_issuer_id).and_return('test-issuer')
    allow(environment).to receive(:app_store_connect_p8_path).and_return('/secure/key.p8')
    Fastlane::Actions.lane_context.delete(Fastlane::Actions::SharedValues::APP_STORE_CONNECT_API_KEY)
    allow(other_actions).to receive(:app_store_connect_api_key).and_return(api_key)
  end

  after { FileUtils.remove_entry(root) }

  it 'uploads only the IPA by default even when release notes are supplied' do
    expect(other_actions).to receive(:upload_to_app_store) do |options|
      expect(options).to include(
        skip_metadata: true, skip_screenshots: true, submit_for_review: false, automatic_release: false
      )
      expect(options).not_to have_key(:release_notes)
      :uploaded
    end
    expect(other_actions).not_to receive(:app_store_resources)
    expect(described_class.run(release_notes: '{"en-US":"Fixes"}', isTestFlight: false)).to eq(:uploaded)
  end

  it 'preserves TestFlight behavior and ignores a store resource config' do
    expect(other_actions).to receive(:upload_to_testflight).with(
      { skip_waiting_for_build_processing: true, api_key: api_key }
    )
    expect(other_actions).not_to receive(:app_store_resources)
    described_class.run(isTestFlight: true, app_store_resources_enabled: true, app_store_resources_config_path: '/missing/resources.json')
  end

  it 'keeps metadata and screenshot synchronization disabled even when Deliverfile enables them' do
    expect(other_actions).to receive(:upload_to_app_store) do |options|
      configuration = FastlaneCore::Configuration.create(Deliver::Options.available_options, options)
      configuration.config_file_options = {
        skip_metadata: false, skip_screenshots: false,
        sync_screenshots: true, overwrite_screenshots: true
      }
      expect(configuration[:skip_metadata]).to be(true)
      expect(configuration[:skip_screenshots]).to be(true)
      expect(configuration[:sync_screenshots]).to be(false)
      expect(configuration[:overwrite_screenshots]).to be(false)
    end
    described_class.run(app_store_resources_enabled: false)
  end

  [nil, false].each do |enabled|
    it "ignores the resource path when the master switch is #{enabled.inspect}" do
      expect(helper).not_to receive(:load_params)
      expect(helper).not_to receive(:prepare)
      expect(other_actions).not_to receive(:app_store_resources)
      expect(other_actions).to receive(:upload_to_app_store).with(hash_including(
        skip_metadata: true, skip_screenshots: true
      ))
      described_class.run(
        app_store_resources_enabled: enabled, app_store_resources_config_path: '/missing/resources.json'
      )
    end
  end

  it 'requires a resource config path when explicitly enabled before authenticating or uploading' do
    expect(helper).not_to receive(:authentication_options)
    expect(other_actions).not_to receive(:upload_to_app_store)
    expect { described_class.run(app_store_resources_enabled: true) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /APP_STORE_RESOURCES_CONFIG_PATH/)
  end

  it 'authenticates from an environment API JSON without requesting P8 credentials' do
    key_path = File.join(root, 'key.json')
    File.write(key_path, '{}')
    allow(environment).to receive(:app_store_connect_api_key_path).and_return(key_path)
    expect(other_actions).not_to receive(:app_store_connect_api_key)
    expect(other_actions).to receive(:upload_to_app_store).with(hash_including(api_key_path: key_path))
    described_class.run(isTestFlight: false)
  end

  it 'checks a new version before IPA upload and forwards the current build and release notes' do
    metadata = File.join(root, 'metadata')
    FileUtils.mkdir_p(metadata)
    File.write(File.join(metadata, 'copyright.txt'), 'Example')
    File.write(config_path, JSON.generate(
      app_identifier: 'com.example.stale', app_version: '0.1', build_number: '1',
      metadata_path: metadata, metadata_changed: false, select_build: true
    ))
    expect(helper).to receive(:metadata_required_for_new_version?).with(hash_including(
      app_identifier: 'com.example.current', app_version: '1.2.3', build_number: '42', api_key: api_key
    )).ordered.and_return(true)
    expect(other_actions).to receive(:upload_to_app_store).with(hash_including(
      skip_metadata: true, skip_screenshots: true, app_identifier: 'com.example.current', app_version: '1.2.3'
    )).ordered
    expect(other_actions).to receive(:app_store_resources).with(hash_including(
      app_store_resources_enabled: true,
      app_identifier: 'com.example.current', app_version: '1.2.3', build_number: '42',
      metadata_changed: true, upload_metadata_on_new_version: false,
      release_notes: { 'en-US' => 'Fixes' }, select_build: true
    )).ordered
    described_class.run(
      app_store_resources_enabled: true,
      app_store_resources_config_path: config_path, app_identifier: 'com.example.current',
      app_version: '1.2.3', build_number: '42', release_notes: '{"en-US":"Fixes"}'
    )
  end

  it 'stops before IPA upload when configured metadata is missing' do
    File.write(config_path, JSON.generate(
      app_identifier: 'com.example.app', metadata_path: File.join(root, 'missing'),
      upload_metadata_on_new_version: false
    ))
    expect(other_actions).not_to receive(:upload_to_app_store)
    expect { described_class.run(app_store_resources_enabled: true, app_store_resources_config_path: config_path) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /metadata 目录/)
  end
end
