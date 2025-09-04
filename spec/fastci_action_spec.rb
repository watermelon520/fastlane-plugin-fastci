describe Fastlane::Actions::FastciAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The fastci plugin is working!")

      Fastlane::Actions::FastciAction.run(nil)
    end
  end
end
