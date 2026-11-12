require 'spec_helper'

describe Fastlane::Fastci do
  it 'loads the package, store resources and existing Zealot actions' do
    expect(Fastlane::Actions::PackageAction.is_supported?(:ios)).to be(true)
    expect(Fastlane::Actions::AppStoreResourcesAction.is_supported?(:ios)).to be(true)
    expect(Fastlane::Actions::UploadZealotAction.is_supported?(:ios)).to be(true)
  end
end

describe Fastlane::Actions::AppStoreResourcesAction do
  it 'describes App Store Connect resource publishing' do
    expect(described_class.description).to include('metadata')
    expect(described_class.description).to include('截图')
  end
end
