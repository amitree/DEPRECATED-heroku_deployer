require 'amitree/git_client'

describe Amitree::GitClient do
  describe '#stories_worked_on_between' do
    it 'should work' do
      @git = Amitree::GitClient.new('foo/bar', 'username', 'password')
      dummy_commit_messages = ['[#12345] one commit', '[#45678 wip] another commit', '[#123] [#45678] foobar']
      expect(@git).to receive(:commit_messages_between).with('aaa111', 'bbb222').and_return(dummy_commit_messages)
      expect(@git.stories_worked_on_between('aaa111', 'bbb222')).to match_array %w(12345 45678 123)
    end
  end
end
