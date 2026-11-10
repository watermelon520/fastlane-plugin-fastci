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

# Fork-side helper and TestFlight configuration coverage.
describe Fastlane::Helper::AppStoreResourcesHelper do
  let(:resource_root) { File.expand_path('../tmp/app_store_resources', __dir__) }
  let(:metadata_path) { File.join(resource_root, 'metadata') }
  let(:screenshots_path) { File.join(resource_root, 'screenshots') }

  before do
    FileUtils.rm_rf(resource_root)
    FileUtils.mkdir_p(File.join(metadata_path, 'zh-Hans'))
    FileUtils.mkdir_p(File.join(screenshots_path, 'zh-Hans'))
    File.write(File.join(metadata_path, 'zh-Hans', 'description.txt'), 'description')
    File.write(File.join(screenshots_path, 'zh-Hans', '0.png'), 'png')
  end

  after do
    FileUtils.rm_rf(resource_root)
  end

  describe '.resource_options' do
    it 'builds deliver resource options without an IPA upload' do
      options = described_class.resource_options(
        {
          app_identifier: 'com.example.app',
          app_version: '7.0.0',
          metadata_changed: true,
          screenshots_changed: false,
        sync_screenshots: false,
          overwrite_screenshots: false,
          submit_for_review: false,
          automatic_release: false,
          force: true,
          api_key_path: '/tmp/api-key.json'
        },
        metadata_path,
        screenshots_path
      )

      expect(options).to include(
        app_identifier: 'com.example.app',
        app_version: '7.0.0',
        metadata_path: metadata_path,
        screenshots_path: screenshots_path,
        skip_binary_upload: true,
        skip_metadata: false,
        skip_screenshots: true,
        api_key_path: '/tmp/api-key.json'
      )
    end
  end

  describe '.load_params' do
    it 'loads generic values from JSON and lets explicit values override them' do
      config_path = File.join(resource_root, 'resources.json')
      File.write(
        config_path,
        JSON.generate(
          app_identifier: 'com.example.configured',
          app_version: '7.0.0',
          metadata_path: metadata_path,
          screenshots_path: screenshots_path,
          metadata_changed: false,
          screenshots_changed: true
        )
      )

      params = described_class.load_params(
        config_path: config_path,
        app_identifier: 'com.example.override'
      )

      expect(params).to include(
          app_identifier: 'com.example.override',
          app_version: '7.0.0',
          metadata_changed: false,
          screenshots_changed: true,
          sync_screenshots: false,
          overwrite_screenshots: false,
          submit_for_review: false,
          automatic_release: false,
          select_build: false,
          wait_for_build_processing: true,
          build_processing_timeout: 3600,
          build_processing_poll_interval: 30,
          build_processing_retry_limit: 3,
          build_processing_retry_interval: 15,
          force: true
      )
    end

    it 'loads build selection and review settings from JSON' do
      config_path = File.join(resource_root, 'release.json')
      File.write(
        config_path,
        JSON.generate(
          app_identifier: 'com.example.app',
          app_version: '7.0.0',
          build_number: '2026081301',
          select_build: true,
          submit_for_review: true,
          automatic_release: false
        )
      )

      params = described_class.load_params(config_path: config_path)

      expect(params).to include(
        app_version: '7.0.0',
        build_number: '2026081301',
        select_build: true,
        submit_for_review: true,
        automatic_release: false
      )
    end
  end

  describe '.metadata_required_for_new_version?' do
    before do
      allow(described_class).to receive(:authenticate)
      allow(Spaceship::ConnectAPI::App).to receive(:find).with('com.example.app').and_return(app)
      allow(Spaceship::ConnectAPI::Platform).to receive(:map).with('ios').and_return(:ios)
    end

    let(:app) { instance_double('Spaceship::ConnectAPI::App') }
    let(:params) do
      {
        app_identifier: 'com.example.app',
        app_version: '8.0.0',
        platform: 'ios',
        upload_metadata_on_new_version: true
      }
    end

    it 'requires metadata when the target version does not exist' do
      version = nil
      allow(app).to receive(:get_edit_app_store_version).with(platform: :ios).and_return(version)

      expect(described_class.metadata_required_for_new_version?(params)).to be(true)
    end

    it 'does not force metadata when the target version already exists' do
      version = instance_double('Spaceship::ConnectAPI::AppStoreVersion', version_string: '8.0.0')
      allow(app).to receive(:get_edit_app_store_version).with(platform: :ios).and_return(version)

      expect(described_class.metadata_required_for_new_version?(params)).to be(false)
    end
  end

  describe '.review_options' do
    it 'submits the selected build without uploading another IPA' do
      options = described_class.review_options(
        app_identifier: 'com.example.app',
        app_version: '7.0.0',
        build_number: '2026081301',
        platform: 'ios',
        automatic_release: false,
        force: true,
        api_key_path: '/tmp/api-key.json'
      )

      expect(options).to include(
        app_identifier: 'com.example.app',
        app_version: '7.0.0',
        build_number: '2026081301',
        skip_binary_upload: true,
        submit_for_review: true,
        automatic_release: false,
        api_key_path: '/tmp/api-key.json'
      )
    end
  end

  describe '.load_testflight_params' do
    it 'supports direct TestFlight parameters without a config file' do
      params = described_class.load_testflight_params(
        testflight_build_number: '2026081302',
        testflight_changelog: '请测试登录流程。',
        testflight_distribute_external: false,
        testflight_submit_beta_review: false
      )

      expect(params).to include(
        testflight_build_number: '2026081302',
        changelog: '请测试登录流程。',
        distribute_external: false,
        notify_external_testers: false,
        submit_beta_review: false
      )
    end
  end

  describe '.select_build' do
    it 'selects the exact processed build on the editable version' do
      app = instance_double('Spaceship::ConnectAPI::App', id: 'app-id')
      build = instance_double(
        'Spaceship::ConnectAPI::Build',
        id: 'build-id',
        processing_state: Spaceship::ConnectAPI::Build::ProcessingState::VALID
      )
      version = instance_double(
        'Spaceship::ConnectAPI::AppStoreVersion',
        version_string: '7.0.0'
      )

      allow(described_class).to receive(:authenticate)
      allow(described_class).to receive(:find_build).and_return(build)
      allow(Spaceship::ConnectAPI::App).to receive(:find).with('com.example.app').and_return(app)
      allow(Spaceship::ConnectAPI::Platform).to receive(:map).with('ios').and_return(:ios)
      allow(app).to receive(:get_edit_app_store_version).with(platform: :ios).and_return(version)
      allow(version).to receive(:select_build).with(build_id: 'build-id')

      described_class.select_build(
        app_identifier: 'com.example.app',
        app_version: '7.0.0',
        build_number: '2026081301',
        platform: 'ios',
        wait_for_build_processing: true
      )

      expect(version).to have_received(:select_build).with(build_id: 'build-id')
    end

    it 'requires an explicit build number' do
      expect do
        described_class.select_build(
          app_identifier: 'com.example.app',
          app_version: '7.0.0',
          platform: 'ios'
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /build_number/)
    end
  end

  describe 'build processing retries' do
    it 'retries a transient SSL error while waiting for an App Store build' do
      app = instance_double('Spaceship::ConnectAPI::App', id: 'app-id')
      build = instance_double('Spaceship::ConnectAPI::Build')
      params = {
        app_version: '7.0.0',
        build_number: '2026081906',
        wait_for_build_processing: true,
        build_processing_timeout: 60,
        build_processing_poll_interval: 30,
        build_processing_retry_limit: 1,
        build_processing_retry_interval: 0
      }

      allow(FastlaneCore::BuildWatcher).to receive(:wait_for_build_processing_to_be_complete)
        .and_raise(OpenSSL::SSL::SSLError, 'SSL_connect returned=1 unexpected eof while reading')
        .then_return(build)

      expect(described_class.send(:find_build, params, app, :ios)).to eq(build)
      expect(FastlaneCore::BuildWatcher).to have_received(:wait_for_build_processing_to_be_complete).twice
    end
  end

  describe '.validate_metadata' do
    it 'rejects an empty metadata directory' do
      FileUtils.rm_rf(Dir[File.join(metadata_path, '**', '*.txt')])

      expect do
        described_class.validate_metadata(metadata_path)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /metadata 目录为空/)
    end
  end

  describe '.validate_screenshots' do
    it 'accepts a directory containing supported screenshot files' do
      expect do
        described_class.validate_screenshots(screenshots_path)
      end.not_to raise_error
    end
  end
end
