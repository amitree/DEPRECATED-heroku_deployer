require 'amitree/git_client'
require 'amitree/heroku_client'
require 'pivotal-tracker'

module Amitree
  class HerokuDeployer
    attr_reader :tracker_project

    class ReleaseDetails
      attr_accessor :production_release, :staging_release_to_deploy, :stories
      attr_writer :production_promoted_from_staging

      def initialize
        @stories = []
      end

      def production_promoted_from_staging?
        @production_promoted_from_staging
      end

      class Story < DelegateClass(PivotalTracker::Story)
        attr_accessor :deliverable
        attr_reader :blocked_by

        def initialize(tracker_story)
          super(tracker_story)
          @deliverable = false
          @blocked_by = []
        end

        def blocked_by=(blocked_by)
          @blocked_by = blocked_by
          if @blocked_by.length > 0
            @deliverable = false
          else
            @deliverable = true
          end
        end
      end
    end

    def initialize(options={})
      @heroku = options[:heroku] || Amitree::HerokuClient.new(options[:heroku_api_key], options[:heroku_staging_app], options[:heroku_production_app])
      @git = options[:git] || Amitree::GitClient.new(options[:github_repo], options[:github_username], options[:github_password])
      PivotalTracker::Client.token = options[:tracker_token]
      @tracker_project = PivotalTracker::Project.find(options[:tracker_project_id])
      @tracker_cache = {}
    end

    def compute_release(options={})
      result = ReleaseDetails.new

      result.production_release = @heroku.last_promoted_production_release
      result.production_promoted_from_staging = @heroku.promoted_from_staging?(result.production_release)
      staging_releases = @heroku.staging_releases_since(@heroku.staging_release_version(result.production_release))

      prod_commit = @heroku.get_production_commit(result.production_release)
      puts "Production release is #{prod_commit}" if options[:verbose]

      result.stories = stories_worked_on_between(prod_commit, 'HEAD')
      all_stories = Hash[result.stories.map{|story| [story.id, story]}]

      staging_releases.reverse.each do |staging_release|
        staging_commit = @heroku.get_staging_commit(staging_release)
        stories = all_stories.values_at(*@git.stories_worked_on_between(prod_commit, staging_commit)).compact
        story_ids = stories.map(&:id)

        puts "- Trying staging release v#{staging_release['version']} with commit #{staging_commit}" if options[:verbose]
        puts "  - Stories: #{story_ids.inspect}" if options[:verbose]

        unaccepted_story_ids = story_ids.select { |story_id| get_tracker_status(story_id) != 'accepted' }

        if unaccepted_story_ids.length > 0
          stories.each do |story|
            story.blocked_by = unaccepted_story_ids
          end
          puts "    - Some stories are not yet accepted: #{unaccepted_story_ids.inspect}" if options[:verbose]
        else
          story_ids_referenced_later = story_ids & @git.stories_worked_on_between(staging_commit, 'HEAD')
          if story_ids_referenced_later.length > 0
            puts "    - Some stories have been worked on in a later commit: #{story_ids_referenced_later}" if options[:verbose]
          else
            stories.each do |story|
              story.blocked_by = unaccepted_story_ids
            end
            puts "    - This release is good to go!" if options[:verbose]
            result.staging_release_to_deploy = staging_release
            break
          end
        end
      end

      return result
    end

    def get_tracker_status(story_id)
      tracker_data(story_id).current_state
    end

    def tracker_data(story_id)
      @tracker_cache[story_id] ||= @tracker_project.stories.find(story_id)
    end

    def stories_worked_on_between(rev1, rev2)
      @git.stories_worked_on_between(rev1, rev2).map do |story_id|
        if story = tracker_data(story_id)
          ReleaseDetails::Story.new(story)
        end
      end.compact
    end
  end
end
