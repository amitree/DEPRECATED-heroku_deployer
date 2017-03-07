require 'amitree/git_client'
require 'webmock/rspec'

describe Amitree::GitClient do
  let(:max_commit_range) { 1000 }
  let(:git) { Amitree::GitClient.new('foo/bar', 'username', 'password', max_commit_range: max_commit_range) }

  before do
    stub_request(:get, 'https://api.github.com/repos/foo/bar/commits?per_page=100').to_return File.new('spec/data/commits/page1.txt')
    stub_request(:get, 'https://api.github.com/repositories/123/commits?per_page=100&page=2').to_return File.new('spec/data/commits/page2.txt')
    stub_request(:get, 'https://api.github.com/repositories/123/commits?per_page=100&page=3').to_return File.new('spec/data/commits/page3.txt')
    stub_request(:get, 'https://api.github.com/repositories/123/commits?per_page=100&page=4').to_return File.new('spec/data/commits/page4.txt')
  end

  describe '#commits_since' do
    context 'commit found in first page of results' do
      specify do
        expect(git.commits_since('77777777').map(&:sha)).to eq ['888888888888', '999999999999']
      end
    end

    context 'pagination is required' do
      it "handles 2 pages" do
        expect(git.commits_since('5555555').map(&:sha)).to eq ['666666666666', '777777777777', '888888888888', '999999999999']
      end
      it "handles 3 pages" do
        expect(git.commits_since('11111111').map(&:sha)).to eq ['222222222222', '333333333333', '444444444444', '555555555555', '666666666666', '777777777777', '888888888888', '999999999999']
      end
      it "handles 4 pages" do
        expect(git.commits_since('abcdef').map(&:sha)).to eq ['000000000000', '111111111111', '222222222222', '333333333333', '444444444444', '555555555555', '666666666666', '777777777777', '888888888888', '999999999999']
      end
    end

    context 'max_commit_range is reached' do
      let(:max_commit_range) { 9 }
      specify do
        expect { git.commits_since('000000') }.to raise_error(Amitree::GitClient::NotFoundError)
      end
    end

    context 'end of results is reached before commit is found' do
      specify do
        expect { git.commits_since('987654') }.to raise_error(Amitree::GitClient::NotFoundError)
      end
    end

    context 'empty page of results is received' do
      before do
        stub_request(:get, 'https://api.github.com/repos/foo/bar/commits?per_page=100').to_return File.new('spec/data/commits/empty.txt')
      end

      specify do
        expect { git.commits_since('abcdef') }.to raise_error "Empty response received from GitHub!"
      end
    end
  end

  describe '#range_since' do
    it 'returns a Range' do
      range = git.range_since('11111111')
      expect(range.commit_messages).to eq [
        'Commit 222222222222',
        'Commit 333333333333',
        'Commit 444444444444',
        'Commit 555555555555',
        'Commit 666666666666',
        'Commit 777777777777',
        'Commit 888888888888',
        'Commit 999999999999',
      ]
    end
  end
end
