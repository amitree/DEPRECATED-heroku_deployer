require 'amitree/heroku_deployer'
require 'ostruct'

# Consider the following case:

# Staging release 0 is a commit for story #5678
# Staging release 1 is a commit for story #1234
# Staging release 2 is a commit for story #4567
# Staging release 3 is a commit for story #1234

# Stories #5678 and #1234 have been tested and accepted.  Story #4567 has not.

describe Amitree::HerokuDeployer do
  let(:heroku) { double(last_promoted_production_release: production_release, :promoted_from_staging? => true, staging_release_name: nil, staging_releases_since: staging_releases) }
  let(:git) { double() }
  let(:tracker_project) { double() }
  let(:deployer) { Amitree::HerokuDeployer.new(heroku: heroku, git: git) }

  before do
    allow(PivotalTracker::Project).to receive(:find).and_return(tracker_project)
    staging_releases.each_with_index do |staging_release, index|
      allow(git).to receive(:stories_worked_on_between).with(production_release['commit'], staging_release['commit']).and_return staging_releases[0..index].map{|release| release['story_id']}.uniq
    end
    releases.each_with_index do |release, index|
      allow(git).to receive(:stories_worked_on_between).with(release['commit'], 'HEAD').and_return releases[index+1..-1].map{|release| release['story_id']}.uniq
    end
    stories.each do |story|
      allow(deployer).to receive(:tracker_data).with(story.id).and_return(story)
    end
  end

  describe '#compute_release' do
    context 'incomplete stories' do
      let!(:stories) {[
        mock_story(5678, 'accepted'),
        mock_story(1234, 'accepted'),
        mock_story(4567, 'rejected')
      ]}

      let!(:releases) {[
        mock_release('Current production release'),
        mock_release('[#5678] release 0', 5678),
        mock_release('[#1234] release 1', 1234),
        mock_release('[#4567] release 2', 4567),
        mock_release('[#1234] release 3', 1234)
      ]}

      let(:production_release) { releases[0] }
      let(:staging_releases) { releases[1..-1] }

      let(:result) { deployer.compute_release }
      it "should not be released" do
        expect(result.staging_release_to_deploy).to eq staging_releases[0]
      end

      it "should set blocked_by correctly" do
        expect(result.stories[0].blocked_by).to eq []
        expect(result.stories[1].blocked_by).to eq [4567]
      end
    end
  end
end

def mock_release(git_commit_msg, story_id=nil)
  { 'commit' => git_commit_msg, 'name' => git_commit_msg, 'story_id' => story_id }
end

def mock_story(id, current_state)
  OpenStruct.new(id: id, current_state: current_state)
end
