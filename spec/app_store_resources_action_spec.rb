require 'spec_helper'
require 'tmpdir'
require 'deliver'
require 'deliver/setup'
require 'deliver/download_screenshots'

describe Fastlane::Actions::AppStoreResourcesAction do
  let(:helper) { Fastlane::Helper::AppStoreResourcesHelper }
  let(:other_actions) { double('other actions') }
  let(:root) { Dir.mktmpdir('fastci-store-spec') }
  let(:metadata) { File.join(root, 'metadata') }
  let(:screenshots) { File.join(root, 'screenshots') }
  let(:config_path) { File.join(root, 'resources.json') }
  let(:settings) do
    {
      app_identifier: 'com.example.app', app_version: '1.2.3',
      metadata_path: metadata, screenshots_path: screenshots,
      upload_metadata_on_new_version: false, api_key: { key_id: 'test', key: 'test' }
    }
  end

  before do
    allow(described_class).to receive(:other_action).and_return(other_actions)
    FileUtils.mkdir_p(File.join(metadata, 'en-US'))
    File.write(File.join(metadata, 'en-US', 'description.txt'), 'Example description')
    FileUtils.mkdir_p(File.join(screenshots, 'en-US'))
    File.write(File.join(screenshots, 'en-US', '1.png'), 'example screenshot')
  end

  after { FileUtils.remove_entry(root) }

  def configuration(settings, overrides = {})
    File.write(config_path, JSON.generate(settings))
    FastlaneCore::Configuration.create(
      described_class.available_options,
      { app_store_resources_enabled: true, config_path: config_path }.merge(overrides)
    )
  end

  it 'skips before reading configuration or authenticating when the master switch is absent' do
    params = FastlaneCore::Configuration.create(described_class.available_options, {
      config_path: '/missing/resources.json', metadata_changed: true, screenshots_changed: true,
      download_missing_metadata: true, download_missing_screenshots: true,
      select_build: true, submit_for_review: true
    })
    expect(helper).not_to receive(:load_params)
    expect(helper).not_to receive(:authentication_options)
    expect(helper).not_to receive(:prepare)
    expect(helper).not_to receive(:select_build)
    expect(other_actions).not_to receive(:upload_to_app_store)
    expect(described_class.run(params)).to be_nil
  end

  it 'does not let enabled resource settings bypass an explicit false master switch' do
    expect(helper).not_to receive(:load_params)
    expect(other_actions).not_to receive(:upload_to_app_store)
    expect(described_class.run(configuration(settings.merge(
      metadata_changed: true, screenshots_changed: true, submit_for_review: true
    ), app_store_resources_enabled: false))).to be_nil
  end

  it 'uploads metadata only with no binary, review or automatic release after explicitly enabling resources' do
    expect(other_actions).to receive(:upload_to_app_store).with(hash_including(
      metadata_path: metadata, skip_binary_upload: true, skip_metadata: false,
      skip_screenshots: true, submit_for_review: false, automatic_release: false
    ))
    expect(helper).not_to receive(:select_build)
    described_class.run(configuration(settings))
  end

  it 'lets an explicit false override a true from JSON using real Fastlane configuration' do
    params = helper.load_params(configuration(settings.merge(screenshots_changed: true), screenshots_changed: false))
    expect(params[:screenshots_changed]).to be(false)
  end

  it 'keeps JSON false values when action defaults are true' do
    params = helper.load_params(configuration(settings.merge(metadata_changed: false, force: false)))
    expect(params.values_at(:metadata_changed, :force)).to eq([false, false])
  end

  it 'uploads screenshots independently without requiring a metadata directory' do
    FileUtils.rm_rf(metadata)
    expect(other_actions).to receive(:upload_to_app_store).with(hash_including(
      skip_metadata: true, skip_screenshots: false, overwrite_screenshots: false
    ))
    described_class.run(configuration(settings.merge(metadata_changed: false, screenshots_changed: true)))
  end

  it 'does not synchronize or replace screenshots when their upload switch is off' do
    expect(other_actions).to receive(:upload_to_app_store).with(hash_including(
      skip_screenshots: true, sync_screenshots: false, overwrite_screenshots: false
    ))
    described_class.run(configuration(settings.merge(
      screenshots_changed: false, sync_screenshots: true, overwrite_screenshots: true
    )))
  end

  it 'skips all uploads when neither resource changed' do
    FileUtils.rm_rf([metadata, screenshots])
    expect(other_actions).not_to receive(:upload_to_app_store)
    described_class.run(configuration(settings.merge(metadata_changed: false, screenshots_changed: false)))
  end

  it 'checks new versions before deciding to skip metadata' do
    expect(helper).to receive(:metadata_required_for_new_version?).and_return(true)
    expect(other_actions).to receive(:upload_to_app_store).with(hash_including(skip_metadata: false))
    described_class.run(configuration(settings.merge(metadata_changed: false, upload_metadata_on_new_version: true)))
  end

  it 'selects the requested build and submits review only when enabled' do
    expect(helper).to receive(:select_build).with(hash_including(build_number: '42')).ordered
    expect(other_actions).to receive(:upload_to_app_store).with(hash_including(
      build_number: '42', skip_binary_upload: true, skip_metadata: true,
      submit_for_review: true, automatic_release: false
    )).ordered
    described_class.run(configuration(settings.merge(metadata_changed: false, submit_for_review: true, build_number: '42')))
  end

  it 'fails before uploading if build selection has no build number' do
    expect(other_actions).not_to receive(:upload_to_app_store)
    expect { described_class.run(configuration(settings.merge(select_build: true))) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /build_number/)
  end

  it 'rejects an empty resource directory before uploading' do
    FileUtils.rm_rf(Dir[File.join(metadata, '**', '*.txt')])
    expect(other_actions).not_to receive(:upload_to_app_store)
    expect { described_class.run(configuration(settings)) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /metadata 目录为空/)
  end

  it 'rejects a nested project config rather than silently ignoring it' do
    expect { helper.load_params(configuration(project: { bundle_id: 'com.example.app' })) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /不支持的字段/)
  end

  it 'rejects malformed JSON without printing its contents' do
    File.write(config_path, '{"secret": "private-value"')
    expect { helper.load_params(config_path: config_path) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /不是有效 JSON/) { |error| expect(error.message).not_to include('private-value') }
  end

  it 'rejects invalid boolean and timeout values from JSON' do
    expect { helper.load_params(configuration(settings.merge(submit_for_review: 'maybe'))) }
      .to raise_error(FastlaneCore::Interface::FastlaneError)
    expect { helper.load_params(configuration(settings.merge(build_processing_timeout: 0))) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /必须大于 0/)
  end

  it 'converts a string false through Fastlane instead of treating it as enabled' do
    params = helper.load_params(configuration(settings.merge(submit_for_review: 'false')))
    expect(params[:submit_for_review]).to be(false)
  end

  it 'rejects conflicting authentication from JSON' do
    key_file = File.join(root, 'key.json')
    File.write(key_file, '{}')
    expect { helper.load_params(configuration(settings.merge(api_key_path: key_file))) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /conflict|cannot use/i)
  end

  it 'bootstraps missing resources using a validated deliver configuration' do
    FileUtils.rm_rf([metadata, screenshots])
    app = instance_double('Spaceship::ConnectAPI::App')
    version = instance_double('Spaceship::ConnectAPI::AppStoreVersion', version_string: '1.2.3')
    allow(Deliver::Runner).to receive(:new) do |options, skip|
      expect(options).to be_a(FastlaneCore::Configuration)
      expect(skip).to eq(skip_version: true)
      Deliver.cache[:app] = app
    end
    allow(app).to receive(:get_latest_app_store_version).and_return(version)
    setup = instance_double('Deliver::Setup')
    allow(Deliver::Setup).to receive(:new).and_return(setup)
    expect(setup).to receive(:generate_metadata_files).with(app, version, metadata, anything)
    expect(Deliver::DownloadScreenshots).to receive(:download).with(anything, screenshots)
    expect(other_actions).not_to receive(:upload_to_app_store)
    described_class.run(configuration(settings.merge(
      metadata_changed: false, download_missing_metadata: true, download_missing_screenshots: true
    )))
  end

  it 'does not overwrite existing local resources when bootstrap is enabled' do
    expect(Deliver::Runner).not_to receive(:new)
    expect(other_actions).not_to receive(:upload_to_app_store)
    described_class.run(configuration(settings.merge(
      metadata_changed: false, download_missing_metadata: true, download_missing_screenshots: true
    )))
  end
end
