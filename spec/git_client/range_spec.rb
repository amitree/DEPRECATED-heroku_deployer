require 'amitree/git_client'
require 'ostruct'

describe Amitree::GitClient::Range do
  let(:commits) { messages.map{|message| OpenStruct.new(commit: OpenStruct.new(message: message))} }
  let(:git_range) { Amitree::GitClient::Range.new(commits) }

  describe '#story_ids' do
    subject { git_range.story_ids }

    context 'story numbers in brackets' do
      let(:messages) { ['[#12345] one commit', '[#45678 wip] another commit', '[#123] [#45678] foobar'] }
      it { is_expected.to match_array [12345, 45678, 123] }
    end

    context 'story numbers not in brackes' do
      let(:messages) { ["[#12345] foo #456\nsomething about [finishes #789]"] }
      it { is_expected.to match_array [12345, 789] }
    end
  end

  describe '#commit_messages' do
    subject { git_range.commit_messages }
    let(:messages) { ['message 1', 'message 2', 'message 1'] }
    it { is_expected.to match_array ['message 1', 'message 2', 'message 1'] }
  end

  describe '#commits' do
    subject { git_range.commits }
    let(:messages) { ['message 1', 'message 2', 'message 1'] }
    it { is_expected.to eq commits }
  end

  describe '#since' do
    let(:shas) { ['2345678', '1234567', '2222222', '1111111', '0123456'] }
    let(:commits) { shas.map { |sha| OpenStruct.new(sha: sha, commit: OpenStruct.new(message: "Commit #{sha}")) } }
    subject { git_range.since(sha).commit_messages }

    context 'valid commit' do
      let(:sha) { '1234567' }
      it { is_expected.to eq ["Commit 2222222", "Commit 1111111", "Commit 0123456"] }
    end

    context 'nonexistent commit' do
      let(:sha) { '9999999' }
      specify { expect { subject }.to raise_error Amitree::GitClient::NotFoundError }
    end

    context 'range of length 1' do
      let(:sha) { '1111111' }
      it { is_expected.to eq ["Commit 0123456"] }
    end

    context 'empty range' do
      let(:sha) { '0123456' }
      it { is_expected.to eq [] }
    end
  end

  describe '#up_to' do
    let(:shas) { ['2345678', '1234567', '2222222', '1111111', '0123456'] }
    let(:commits) { shas.map { |sha| OpenStruct.new(sha: sha, commit: OpenStruct.new(message: "Commit #{sha}")) } }
    subject { git_range.up_to(sha).commit_messages }

    context 'valid commit' do
      let(:sha) { '1234567' }
      it { is_expected.to eq ["Commit 2345678", "Commit 1234567"] }
    end

    context 'nonexistent commit' do
      let(:sha) { '9999999' }
      specify { expect { subject }.to raise_error Amitree::GitClient::NotFoundError }
    end

    context 'range of length 1' do
      let(:sha) { '2345678' }
      it { is_expected.to eq ["Commit 2345678"] }
    end

    context 'entire range' do
      let(:sha) { '0123456' }
      it { is_expected.to eq ["Commit 2345678", "Commit 1234567", "Commit 2222222", "Commit 1111111", "Commit 0123456"] }
    end
  end
end

