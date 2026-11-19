require 'spec_helper'

describe Fastlane::Actions::PackageAction do
  let(:environment) { Fastlane::Helper::Environment }

  it 'adds the Live Activity profile to export options' do
    allow(environment).to receive_messages(
      bundleID: 'com.example.app',
      provisioningProfiles_adhoc: 'Example AdHoc',
      extension_bundle_ids: ['com.example.push'],
      extension_profiles_adhoc: ['Example Push AdHoc'],
      activity_bundle_id: 'com.example.app.activity',
      activity_profile_adhoc: 'Example Activity AdHoc'
    )

    expect(described_class.provisioning_profiles_map('ad-hoc')).to eq(
      'com.example.app' => 'Example AdHoc',
      'com.example.push' => 'Example Push AdHoc',
      'com.example.app.activity' => 'Example Activity AdHoc'
    )
  end

  it 'keeps the existing generic Extension configuration working' do
    allow(environment).to receive_messages(
      bundleID: 'com.example.app',
      provisioningProfiles_development: 'Example Development',
      extension_bundle_ids: ['com.example.push'],
      extension_profiles_development: ['Example Push Development'],
      activity_bundle_id: '',
      activity_profile_development: ''
    )

    expect(described_class.provisioning_profiles_map('development')).to eq(
      'com.example.app' => 'Example Development',
      'com.example.push' => 'Example Push Development'
    )
  end
end
