require 'spec_helper'

describe Fastlane::Helper::DingdingHelper do
  let(:environment) { Fastlane::Helper::Environment }

  before { allow(environment).to receive(:dingdingToken).and_return('example-token') }

  it 'serializes quoted, multiline and shell-like text as JSON without executing it' do
    text = "修复 \"引号\" 和 '单引号'\n$(example) `example` \\ 路径"
    expect(Open3).to receive(:capture3) do |*arguments, stdin_data:|
      # 凭据与正文只走 stdin；禁止 shell 拼接或关闭证书校验。
      expect(arguments.first(2)).to eq(['/usr/bin/curl', '--disable'])
      expect(arguments).not_to include('--insecure', '-k', 'example-token', text)
      expect(arguments.join(' ')).not_to include('access_token')
      configuration = stdin_data.lines.to_h do |line|
        key, value = line.split(' = ', 2)
        [key, JSON.parse(value)]
      end
      expect(JSON.parse(configuration.fetch('data-binary'))).to eq(
        'msgtype' => 'markdown', 'markdown' => { 'title' => 'ExampleApp iOS', 'text' => text }
      )
      expect(URI(configuration.fetch('url')).query).to eq('access_token=example-token')
      ["{\"errcode\":0,\"errmsg\":\"ok\"}\n200", '', double(success?: true)]
    end
    expect(described_class.sendMarkdown(text, title: 'ExampleApp iOS')).to be(true)
  end

  it 'makes no request without a token' do
    allow(environment).to receive(:dingdingToken).and_return(' ')
    expect(Open3).not_to receive(:capture3)
    expect(described_class.sendMarkdown('ExampleApp iOS')).to be(false)
  end

  it 'does not fail the build or log credentials when the request times out' do
    allow(Open3).to receive(:capture3).and_return(['', 'access_token=example-token', double(success?: false, exitstatus: 28)])
    expect(Fastlane::UI).to receive(:important) do |message|
      expect(message).to include('curl exit=28')
      expect(message).not_to include('example-token')
    end
    expect(described_class.sendMarkdown('ExampleApp iOS')).to be(false)
  end

  ['{"errcode":310000,"errmsg":"rejected"}', 'invalid JSON', '[]'].each do |body|
    it "does not report successful delivery for #{body}" do
      allow(described_class).to receive(:post_message).and_return(code: 200, body: body)
      expect(described_class.sendMarkdown('ExampleApp iOS')).to be(false)
    end
  end

  it 'handles an unsuccessful HTTP response without logging its body' do
    allow(described_class).to receive(:post_message).and_return(code: 400, body: 'access_token=example-token')
    expect(Fastlane::UI).to receive(:important) do |message|
      expect(message).to include('HTTP 400')
      expect(message).not_to include('example-token')
    end
    expect(described_class.sendMarkdown('ExampleApp iOS')).to be(false)
  end

  it 'does not leak credentials when launching curl raises an exception' do
    allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT, 'access_token=example-token')
    expect(Fastlane::UI).to receive(:important) do |message|
      expect(message).to include('Errno::ENOENT')
      expect(message).not_to include('example-token')
    end
    expect(described_class.sendMarkdown('ExampleApp iOS')).to be(false)
  end
end
