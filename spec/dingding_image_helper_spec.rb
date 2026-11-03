require 'spec_helper'

describe Fastlane::Helper::DingdingImageHelper do
  let(:url) { 'https://example.com/qr?signature=private-value' }
  let(:png) { Base64.strict_decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==') }

  it 'embeds downloaded bytes without leaking the URL and removes the temporary file' do
    temporary_path = nil
    expect(Open3).to receive(:capture3) do |*arguments, stdin_data:|
      expect(arguments.first(2)).to eq(['/usr/bin/curl', '--disable'])
      expect(arguments).not_to include('--insecure', '-k', url)
      expect(arguments.join(' ')).not_to include('private-value')
      expect(arguments).to include('--max-filesize', described_class::MAX_IMAGE_BYTES.to_s, '--max-time', '15')
      expect(JSON.parse(stdin_data.split(' = ', 2).last)).to eq(url)
      temporary_path = arguments[arguments.index('--output') + 1]
      File.binwrite(temporary_path, png)
      ['', '', double(success?: true)]
    end
    source = described_class.base64_source(url)
    expect(source).to start_with('data:image/png;base64,')
    expect(Base64.strict_decode64(source.split(',', 2).last)).to eq(png)
    expect(File.exist?(temporary_path)).to be(false)
  end

  {
    'empty response' => '',
    'HTML login page' => '<html>Login required</html>',
    'oversized image without a declared length' => "\x89PNG\r\n\x1a\n".b + ('x' * Fastlane::Helper::DingdingImageHelper::MAX_IMAGE_BYTES)
  }.each do |description, data|
    it "falls back for #{description}" do
      allow(Open3).to receive(:capture3) do |*arguments, **_options|
        File.binwrite(arguments[arguments.index('--output') + 1], data)
        ['', '', double(success?: true)]
      end
      expect(described_class.base64_source(url)).to be_nil
    end
  end

  it 'does not interrupt packaging or log signed URLs when downloading fails' do
    allow(Open3).to receive(:capture3).and_return(['', url, double(success?: false, exitstatus: 28)])
    expect(Fastlane::UI).to receive(:important) do |message|
      expect(message).to include('curl exit=28')
      expect(message).not_to include('private-value')
    end
    expect(described_class.base64_source(url)).to be_nil
  end

  it 'does not download local files or URLs containing credentials' do
    expect(Open3).not_to receive(:capture3)
    ['file:///private/image.png', 'https://user:password@example.com/qr'].each do |value|
      expect(described_class.base64_source(value)).to be_nil
    end
  end
end
