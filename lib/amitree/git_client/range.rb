module Amitree
  class GitClient
    class EmptyRangeError < StandardError
    end

    class Range
      def initialize commits
        @commits = commits
      end

      def story_ids
        commit_messages.map do |msg|
          msg.scan(/(?<=\[).*?(?=\])/).map{|expr| expr.scan /(?<=#)\d+/}
        end.flatten.map(&:to_i).uniq
      end

      def commit_messages
        @commits.map(&:commit).map(&:message)
      end

      def since(rev)
        Range.new(@commits[(index(rev)+1)..-1])
      end

      def up_to(rev)
        Range.new(@commits[0..index(rev)])
      end

    private

      def index rev
        @commits.index{|commit| commit.sha.start_with?(rev)} or raise NotFoundError, "Failed to find #{rev} in range"
      end
    end
  end
end
