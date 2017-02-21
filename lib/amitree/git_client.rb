require 'octokit'

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
    end

    def commits_between(rev1, rev2)
      result = @client.compare @repository, rev1, rev2
      result.commits
    end

    def commit_messages_between(rev1, rev2)
      commits_between(rev1, rev2).map(&:commit).map(&:message)
    end

    def stories_worked_on_between(rev1, rev2)
      messages = commit_messages_between(rev1, rev2)
      messages.map do |msg|
        msg.scan(/(?<=\[).*?(?=\])/).map{|expr| expr.scan /(?<=#)\d+/}
      end.flatten.map(&:to_i).uniq
    end

    def link_to(rev)
      "https://github.com/#{@repository}/commit/#{rev}"
    end
  end
end
