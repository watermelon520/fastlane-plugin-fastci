require 'spec_helper'

describe Fastlane::Helper::Environment do
  around do |example|
    values = ENV.values_at('APP_STORE_CONNECT_P8_PATH', 'DINO_APP_STORE_CONNECT_P8_PATH', 'PACKAGE_FILE_FOLDER_NAME', 'CONNECT_KEY_ID')
    example.run
  ensure
    %w[APP_STORE_CONNECT_P8_PATH DINO_APP_STORE_CONNECT_P8_PATH PACKAGE_FILE_FOLDER_NAME CONNECT_KEY_ID].each_with_index do |key, index|
      value = values[index]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  it 'uses the canonical P8 path and ignores the legacy variable' do
    ENV['PACKAGE_FILE_FOLDER_NAME'] = '/secure'
    ENV['CONNECT_KEY_ID'] = 'canonical'
    ENV['DINO_APP_STORE_CONNECT_P8_PATH'] = '/legacy/key.p8'
    ENV['APP_STORE_CONNECT_P8_PATH'] = '/canonical/key.p8'
    expect(described_class.app_store_connect_p8_path).to eq('/canonical/key.p8')
  end

  it 'falls back to the package folder when the canonical variable is absent' do
    ENV.delete('APP_STORE_CONNECT_P8_PATH')
    ENV.delete('DINO_APP_STORE_CONNECT_P8_PATH')
    ENV['PACKAGE_FILE_FOLDER_NAME'] = '/secure'
    ENV['CONNECT_KEY_ID'] = 'canonical'
    expect(described_class.app_store_connect_p8_path).to eq('/secure/AuthKey_canonical.p8')
  end
end
