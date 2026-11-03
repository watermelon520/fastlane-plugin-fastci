require 'spec_helper'

describe Fastlane::Fastci do
  it 'loads the package, store resources and existing Zealot actions' do
    expect(Fastlane::Actions::PackageAction.is_supported?(:ios)).to be(true)
    expect(Fastlane::Actions::AppStoreResourcesAction.is_supported?(:ios)).to be(true)
    expect(Fastlane::Actions::UploadZealotAction.is_supported?(:ios)).to be(true)
  end
end
