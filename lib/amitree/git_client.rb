require 'octokit'
require 'amitree/git_client/range'
require 'amitree/git_client/not_found_error'

module Amitree
  class GitClient
    def self.verbose_middleware
      Octokit::Default::MIDDLEWARE.dup.tap do |middleware|
        middleware.response :logger, nil, bodies: true
      end
    end

    def initialize(repository, username, password, options={})
      @repository = repository
      @client = Octokit::Client.new \
        login: username,
        password: password,
        middleware: (self.class.verbose_middleware if options[:verbose]),
        connection_options: Octokit::Default.options[:connection_options].merge(request: {timeout: 60, open_timeout: 60})
      @max_commit_range = options[:max_commit_range] || 1000
    end

    def commits_since(rev)
      result = []

      @client.commits(@repository, per_page: 100)
      response = @client.last_response

      loop do
        if response.data.length == 0
          raise "Empty response received from GitHub!"
        end

        result.concat response.data

        if index = result.index{|commit| commit.sha.start_with?(rev)}
          return result[0...index].reverse
        end
        if result.length >= @max_commit_range
          raise NotFoundError, "Failed to find #{rev} in the most recent #{@max_commit_range} commits. Consider increasing max_commit_range."
        end
        unless page = response.rels[:next]
          raise NotFoundError, "Failed to find #{rev} in entire commit history."
        end

        response = page.get
      end
    end

    def range_since(rev)
      Range.new(commits_since(rev))
    end

    def link_to(rev)
      "https://github.com/#{@repository}/commit/#{rev}"
    end
  end
end
