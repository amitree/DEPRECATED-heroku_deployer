require 'amitree/heroku_deployer'
require 'ostruct'

# Consider the following case:

# Staging release 0 is a commit for story #5678
# Staging release 1 is a commit for story #1234
# Staging release 2 is a commit for story #4567
# Staging release 3 is a commit for story #1234

# Stories #5678 and #1234 have been tested and accepted.  Story #4567 has not.

describe Amitree::HerokuDeployer do
  let(:heroku) { double(last_promoted_production_release: production_release, :promoted_from_staging? => true, staging_release_version: nil, staging_releases_since: staging_releases) }
  let(:git) { double() }
  let(:tracker_project) { double() }
  let(:deployer) { Amitree::HerokuDeployer.new(heroku: heroku, git: git, **options) }

  before do
    allow(PivotalTracker::Project).to receive(:all).and_return([tracker_project])
    allow(git).to receive(:range_since).with(production_release['commit']).and_return Amitree::GitClient::Range.new(staging_releases.map{|release| OpenStruct.new(sha: release['commit'], commit: OpenStruct.new(message: release['name']))})
    allow(heroku).to receive(:version) {|release| release['commit']}

    stories.each do |story|
      allow(deployer).to receive(:tracker_data).with(story.id).and_return(story)
    end
    allow(heroku).to receive(:get_production_commit) { |release| release['commit'] }
    allow(heroku).to receive(:get_staging_commit) { |release| release['commit'] }
  end

  describe '#compute_release' do
    let(:options) { {} }
    let(:production_release) { releases[0] }
    let(:staging_releases) { releases[1..-1] }
    let(:result) { deployer.compute_release options }

    context 'incomplete stories' do
      let!(:stories) {[
        mock_story(5678, 'accepted'),
        mock_story(1234, 'accepted'),
        mock_story(4567, 'rejected')
      ]}

      let!(:releases) {[
        mock_release('abcdef1', 'Current production release'),
        mock_release('abcdef2', '[#5678] release 0'),
        mock_release('abcdef3', '[#1234] release 1'),
        mock_release('abcdef4', '[#4567] release 2'),
        mock_release('abcdef5', '[#1234] release 3')
      ]}

      it "should not be released" do
        expect(result.staging_release_to_deploy).to eq staging_releases[0]
          expect(result.git_range.commit_messages).to eq ['[#5678] release 0']
      end

      it "should set blocked_by correctly" do
        expect(result.stories[0].blocked_by).to eq []
        expect(result.stories[1].blocked_by).to eq [4567]
      end
    end

    context 'empty release' do
      let!(:stories) { [] }
      let!(:releases) {[
        mock_release('abcdef1', 'Current production release'),
        mock_release('abcdef2', 'release 0')
      ]}

      context 'allow_empty is false (default)' do
        it 'should not be released' do
          expect(result.staging_release_to_deploy).to be_nil
          expect(result.git_range).to be_nil
        end
      end

      context 'allow_empty is true' do
        let(:options) { {allow_empty: true} }
        it 'should be released' do
          expect(result.staging_release_to_deploy).to eq staging_releases[0]
          expect(result.git_range.commit_messages).to eq ['release 0']
        end
      end
    end

    context 'missing story' do
      let!(:stories) {[
        mock_story(5678, 'accepted')
      ]}

      let!(:releases) {[
        mock_release('abcdef1', 'Current production release'),
        mock_release('abcdef2', '[#1234] release 0'),
        mock_release('abcdef3', '[#5678] release 1'),
      ]}

      before do
        allow(deployer).to receive(:tracker_data).with(1234).and_return(nil)
      end

      it "should not include non-existent stories" do
        expect(result.stories.map(&:id)).to eq [5678]
      end

      it "should not allow non-existent stories to block release" do
        expect(result.stories[0].blocked_by).to eq []
      end
    end
  end
end

def mock_release(sha, message)
  { 'commit' => sha, 'name' => message }
end

def mock_story(id, current_state)
  OpenStruct.new(id: id, current_state: current_state)
end
