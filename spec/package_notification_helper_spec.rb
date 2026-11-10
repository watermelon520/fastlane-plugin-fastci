require 'spec_helper'

describe Fastlane::Helper::PackageNotificationHelper do
  let(:transport) { Fastlane::Helper::DingdingHelper }
  let(:environment) { Fastlane::Helper::Environment }
  let(:notice) { described_class.new(scheme: 'ExampleApp', export_method: 'ad-hoc', changelog: "修复问题\n优化体验") }
  let(:messages) { [] }
  let(:inline_qr) { 'data:image/png;base64,aW1hZ2U=' }

  before do
    @previous_env = ENV.to_h.select { |key, _| key.start_with?('DINGDING_') }
    ENV.keys.select { |key| key.start_with?('DINGDING_') }.each { |key| ENV.delete(key) }
    allow(environment).to receive_messages(dingdingToken: 'example-token', bundleID: 'com.example.app',
                                           scheme: 'EnvironmentScheme', pgy_password: 'install-example', fir_password: 'install-example')
    allow(transport).to receive(:sendMarkdown) { |body, title:| messages << { title: title, body: body } }
    allow(Fastlane::Helper::DingdingImageHelper).to receive(:base64_source).and_return(inline_qr)
    notice.build_info(version: '1.2.3', build: '42')
  end

  after do
    ENV.keys.select { |key| key.start_with?('DINGDING_') }.each { |key| ENV.delete(key) }
    ENV.update(@previous_env)
  end

  it 'uses the actual scheme and includes the same identifying fields in each platform message' do
    {
      pgy: { 'fastlaneAddedWholeVisitUrl' => 'https://example.com/install' },
      fir: { download_url: 'https://example.com/install' },
      zealot: { release_id: 42 }, testflight: { uploaded: true }, app_store: { uploaded: true }
    }.each { |platform, result| notice.distribution_completed(platform, result) }

    expect(messages.length).to eq(5)
    messages.each do |message|
      expect(message[:title]).to start_with('ExampleApp iOS · ')
      expect(message[:body]).to include('com.example.app', '1.2.3', '42', 'ad-hoc', 'Debug',
                                        '累计耗时', '通知时间', '更新说明', "修复问题  \n优化体验")
      expect(message[:body]).not_to include('EnvironmentScheme', 'example-token')
    end
  end

  it 'includes Pgyer and fir installation fields and lets configuration hide passwords' do
    notice.distribution_completed(:pgy, { 'fastlaneAddedWholeVisitUrl' => 'https://example.com/app',
                                         'buildQRCodeURL' => 'https://example.com/qr.png' })
    expect(messages.last[:body]).to include('[安装页面](https://example.com/app)',
                                           "![安装二维码](#{inline_qr})", '[打开二维码](https://example.com/qr.png)', 'install-example')
    ENV['DINGDING_INCLUDE_INSTALL_PASSWORD'] = 'false'
    notice.distribution_completed(:fir, { download_url: 'https://example.com/fir' })
    expect(messages.last[:body]).to include('[安装页面](https://example.com/fir)')
    expect(messages.last[:body]).not_to include('安装密码', 'install-example')
  end

  it 'includes all Zealot addresses and the confirmed dSYM status' do
    notice.distribution_completed(:zealot, { release_id: 42, release_url: 'https://example.com/releases/42',
                                            install_url: 'https://example.com/install/42', qrcode_url: 'https://example.com/qr/42',
                                            dsym_status: '已上传' })
    expect(messages.last[:body]).to include('[版本详情](https://example.com/releases/42)',
                                           '[安装页面](https://example.com/install/42)',
                                           "![安装二维码](#{inline_qr})", '[打开二维码](https://example.com/qr/42)', '**dSYM**：已上传')
    expect(messages.length).to eq(1)
  end

  it 'keeps a clickable QR link without a broken image if image embedding fails' do
    allow(Fastlane::Helper::DingdingImageHelper).to receive(:base64_source).and_return(nil)
    notice.distribution_completed(:zealot, { release_id: 42, qrcode_url: 'https://example.com/qr/42' })
    expect(messages.length).to eq(1)
    expect(messages.last[:body]).to include('[打开二维码](https://example.com/qr/42)')
    expect(messages.last[:body]).not_to include('![安装二维码]', '扫码安装')
  end

  it 'labels TestFlight as uploaded but not yet processed and uses only the configured invitation' do
    ENV['DINGDING_TESTFLIGHT_URL'] = 'https://testflight.apple.com/join/example'
    notice.distribution_completed(:testflight, { uploaded: true })
    expect(messages.last[:body]).to include('尚未等待 Apple 处理完成',
                                           '[TestFlight 测试邀请](https://testflight.apple.com/join/example)')
    expect(messages.last[:body]).not_to include('已上线')
  end

  it 'shows only confirmed App Store resource results and labels the live page' do
    ENV['DINGDING_APP_STORE_URL'] = 'https://apps.apple.com/app/id123456789'
    notice.distribution_completed(:app_store, { uploaded: true }, store_result: {
      resources_enabled: true, metadata_uploaded: true, screenshots_uploaded: false,
      build_selected: true, review_submitted: false
    })
    expect(messages.last[:body]).to include('**元数据**：已上传', '**截图**：未上传',
                                           '**提交审核**：未提交', '**构建选择**：已选择本次 Build',
                                           '[App Store 线上页面](https://apps.apple.com/app/id123456789)', '不代表审核通过或已上线')
  end

  it 'shows IPA-only mode when App Store resources are disabled' do
    notice.distribution_completed(:app_store, { uploaded: true }, store_result: { resources_enabled: false })
    expect(messages.last[:body]).to include('未开启，仅上传 IPA')
    expect(messages.last[:body]).not_to include('**元数据**：已上传', 'TestFlight 测试邀请')
  end

  it 'omits empty and unsafe links and escapes Markdown delimiters in a valid URL' do
    notice.distribution_completed(:zealot, { release_url: 'https://user:password@example.com/private',
                                            install_url: 'javascript:alert(1)', qrcode_url: '' })
    expect(messages.last[:body]).not_to include('](', 'password', '扫码安装')
    notice.distribution_completed(:fir, { download_url: 'https://example.com/app(1)' })
    expect(messages.last[:body]).to include('https://example.com/app%281%29')
  end

  it 'does not report success for an empty or missing distribution result' do
    [nil, {}].each { |result| notice.distribution_completed(:zealot, result) }
    expect(messages.map { |message| message[:title] }).to all(include('上传未完成'))
  end

  it 'sends no messages when explicitly disabled or no token is configured' do
    described_class.new(is_notice_dingding: false).distribution_completed(:zealot, { release_id: 42 })
    allow(environment).to receive(:dingdingToken).and_return(nil)
    notice.distribution_completed(:zealot, { release_id: 42 })
    notice.failure
    expect(messages).to be_empty
  end

  it 'does not send a code-check result when no checks ran' do
    notice.checks_completed([])
    expect(messages).to be_empty
    notice.checks_completed(['SwiftLint'])
    expect(messages.last[:body]).to include('SwiftLint', '发现的问题请查看本次生成的报告')
  end

  it 'reports a resource failure separately from a successful binary upload' do
    notice.stage(:app_store, '上传分发包')
    notice.failure(store_result: { stage: '发布商店资源', ipa_uploaded: true })
    expect(messages.last[:body]).to include('**失败阶段**：发布商店资源', '**IPA**：已上传', '执行失败')
  end

  it 'bounds long changelogs without changing the original value' do
    changelog = '新' * 1500
    described_class.new(changelog: changelog).distribution_completed(:zealot, { release_id: 42 })
    expect(messages.last[:body]).to include('新' * 1000, '更新说明已截断')
    expect(messages.last[:body]).not_to include('新' * 1001)
    expect(changelog.length).to eq(1500)
  end
end
