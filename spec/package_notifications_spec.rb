require 'spec_helper'

describe Fastlane::Actions::PackageAction, 'DingTalk notifications' do
  let(:environment) { Fastlane::Helper::Environment }
  let(:actions) { double('other actions') }
  let(:messages) { [] }
  let(:params) { { export_method: 'ad-hoc', scheme: 'ExampleApp', changelog: '修复问题' } }

  before do
    allow(described_class).to receive(:other_action).and_return(actions)
    allow(environment).to receive_messages(
      is_auto_update_provisioning: true, scheme: 'Example', bundleID: 'com.example.app',
      project: nil, workspace: 'Example.xcworkspace', extension_bundle_ids: [],
      connect_key_id: nil, connect_issuer_id: nil, app_store_connect_api_key_path: '',
      sentry_auth_token: nil, pgy_api_key: nil, fir_api_token: nil, zealot_token: nil,
      dingdingToken: 'example-token', pgy_password: nil, fir_password: nil
    )
    allow(actions).to receive(:update_build_number)
    allow(actions).to receive(:get_version_number).and_return('1.2.3')
    allow(actions).to receive(:get_build_number).and_return('42')
    allow(actions).to receive(:gym)
    # 隔离真实文件、平台上传与群机器人，只验证发布编排及消息内容。
    allow(FileUtils).to receive(:rm_rf)
    allow(FileUtils).to receive(:mkdir_p)
    allow(FileUtils).to receive(:cp_r)
    allow(FileUtils).to receive(:cp)
    allow(Fastlane::Helper::DingdingHelper).to receive(:sendMarkdown) do |body, title:|
      messages << { title: title, body: body }
    end
    Fastlane::Actions.lane_context.delete(Fastlane::Actions::SharedValues::FASTCI_STORE_UPLOAD_RESULT)
    Fastlane::Actions.lane_context.delete(Fastlane::Actions::SharedValues::ZEAALOT_ERROR_MESSAGE)
  end

  it 'sends no success notification when no distribution platform is configured' do
    described_class.run(params)
    expect(messages).to be_empty
  end

  it 'sends independent results for all configured test distribution platforms' do
    allow(environment).to receive_messages(pgy_api_key: 'example', fir_api_token: 'example', zealot_token: 'example')
    expect(actions).to receive(:upload_pgy).ordered.and_return('fastlaneAddedWholeVisitUrl' => 'https://example.com/pgy')
    expect(actions).to receive(:upload_fir).with(changelog: '修复问题').ordered.and_return(download_url: 'https://example.com/fir')
    expect(actions).to receive(:upload_zealot).with(file: 'fastlane_cache/temp/ExampleApp_ad-hoc_1.2.3_42.ipa', changelog: '修复问题')
      .ordered.and_return(release_id: 42, install_url: 'https://example.com/zealot')
    described_class.run(params)
    expect(messages.map { |message| message[:title] }).to eq([
      'ExampleApp iOS · 蒲公英 · 上传完成',
      'ExampleApp iOS · fir · 上传完成', 'ExampleApp iOS · Zealot · 上传完成'
    ])
    expect(messages[0][:body]).not_to include('https://example.com/fir', 'https://example.com/zealot')
  end

  it 'preserves an earlier upload success and re-raises a later platform failure' do
    allow(environment).to receive_messages(pgy_api_key: 'example', fir_api_token: 'example')
    allow(actions).to receive(:upload_pgy).and_return('fastlaneAddedWholeVisitUrl' => 'https://example.com/pgy')
    failure = RuntimeError.new('private-error-detail')
    allow(actions).to receive(:upload_fir).and_raise(failure)
    expect { described_class.run(params) }.to(raise_error { |error| expect(error).to equal(failure) })
    expect(messages[0][:title]).to include('蒲公英 · 上传完成')
    expect(messages.last[:title]).to include('fir · 执行失败')
    expect(messages.last[:body]).to include('**失败阶段**：上传 IPA')
    expect(messages.last[:body]).not_to include('private-error-detail')
  end

  it 'reports a build failure without a build-completed or upload-completed message' do
    allow(actions).to receive(:gym).and_raise('build failed')
    expect { described_class.run(params) }.to raise_error('build failed')
    expect(messages.length).to eq(1)
    expect(messages.first[:body]).to include('构建 IPA', '执行失败', '1.2.3')
    expect(messages.first[:body]).not_to include('打包完成', '上传完成')
  end

  it 'respects the explicit notification switch on success and failure' do
    allow(environment).to receive(:zealot_token).and_return('example')
    allow(actions).to receive(:upload_zealot).and_return(release_id: 42)
    described_class.run(params.merge(is_notice_dingding: false))
    allow(actions).to receive(:gym).and_raise('build failed')
    expect { described_class.run(params.merge(is_notice_dingding: false)) }.to raise_error('build failed')
    expect(messages).to be_empty
  end

  it 'does not report skipped code checks for App Store builds' do
    expect(actions).not_to receive(:analyze_swiftlint)
    described_class.run(params.merge(export_method: 'app-store', is_analyze_swiftlint: true))
    expect(messages.map { |message| message[:title] }).to eq([
      'ExampleApp iOS · App Store · 未上传'
    ])
  end

  it 'lists only checks that actually ran on a test package' do
    expect(actions).to receive(:analyze_swiftlint).with(is_from_package: true, configuration: 'Debug')
    expect(actions).not_to receive(:detect_duplicity_code)
    described_class.run(params.merge(is_analyze_swiftlint: true))
    expect(messages.last[:body]).to include('检查执行完成', 'SwiftLint')
    expect(messages.last[:body]).not_to include('重复代码')
  end

  it 'does not claim Zealot succeeded when fail_on_error=false returns no release' do
    allow(environment).to receive(:zealot_token).and_return('example')
    allow(actions).to receive(:upload_zealot).and_return(nil)
    expect(actions).not_to receive(:upload_zealot_dsym)
    described_class.run(params.merge(is_upload_zealot_dsym: true))
    expect(messages.last[:title]).to include('Zealot · 上传未完成')
  end

  it 'distinguishes a failed Zealot symbol upload from a successful IPA upload' do
    allow(environment).to receive(:zealot_token).and_return('example')
    allow(actions).to receive(:upload_zealot).and_return(release_id: 42)
    allow(actions).to receive(:upload_zealot_dsym).and_raise('symbol upload failed')
    expect { described_class.run(params.merge(is_upload_zealot_dsym: true)) }.to raise_error('symbol upload failed')
    expect(messages.last[:body]).to include('上传 dSYM（IPA 已上传）', '执行失败')
  end

  it 'uses the exact store progress record on resource publication failure' do
    allow(environment).to receive(:app_store_connect_api_key_path).and_return('/secure/key.json')
    allow(actions).to receive(:upload_store) do
      Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::FASTCI_STORE_UPLOAD_RESULT] = {
        stage: '发布商店资源', ipa_uploaded: true
      }
      raise 'resource upload failed'
    end
    expect { described_class.run(params.merge(export_method: 'app-store')) }.to raise_error('resource upload failed')
    expect(messages.last[:body]).to include('发布商店资源', '**IPA**：已上传')
  end
end
