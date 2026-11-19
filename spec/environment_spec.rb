require 'spec_helper'

describe Fastlane::Helper::Environment do
  around do |example|
    keys = %w[
      APP_STORE_CONNECT_P8_PATH DINO_APP_STORE_CONNECT_P8_PATH PACKAGE_FILE_FOLDER_NAME CONNECT_KEY_ID
      DYNAMIC_ISLAND_BUNDLE_ID DYNAMIC_ISLAND_BUNDLE_IDS DYNAMIC_ISLAND_PROFILE_DEVELOPMENT
      DYNAMIC_ISLAND_PROFILE_ADHOC DYNAMIC_ISLAND_PROFILE_APPSTORE DYNAMIC_ISLAND_PROFILES_DEVELOPMENT
      DYNAMIC_ISLAND_PROFILES_ADHOC DYNAMIC_ISLAND_PROFILES_APPSTORE
    ]
    values = ENV.values_at(*keys)
    example.run
  ensure
    keys.each_with_index do |key, index|
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

  it 'reads the dedicated Dynamic Island profile and bundle configuration' do
    ENV['DYNAMIC_ISLAND_BUNDLE_ID'] = 'com.example.app.LiveActivity'
    ENV['DYNAMIC_ISLAND_PROFILE_DEVELOPMENT'] = 'ExampleApp LiveActivity Development'

    expect(described_class.dynamic_island_bundle_ids).to eq(['com.example.app.LiveActivity'])
    expect(described_class.dynamic_island_profiles_development).to eq(['ExampleApp LiveActivity Development'])
    expect(described_class.dynamic_island_profile_development).to eq('ExampleApp LiveActivity Development')
  end

  it 'prefers plural Dynamic Island values when multiple targets are configured' do
    ENV['DYNAMIC_ISLAND_BUNDLE_ID'] = 'ignored'
    ENV['DYNAMIC_ISLAND_BUNDLE_IDS'] = 'com.example.one.LiveActivity, com.example.two.LiveActivity'
    ENV['DYNAMIC_ISLAND_PROFILE_DEVELOPMENT'] = 'ignored'
    ENV['DYNAMIC_ISLAND_PROFILES_DEVELOPMENT'] = 'One Development,Two Development'

    expect(described_class.dynamic_island_bundle_ids).to eq([
      'com.example.one.LiveActivity', 'com.example.two.LiveActivity'
    ])
    expect(described_class.dynamic_island_profiles_development).to eq(['One Development', 'Two Development'])
  end
end
