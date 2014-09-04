require 'platform-api'
require 'rendezvous'

module Amitree
  class HerokuClient
    class Error < StandardError
    end

    class PostDeploymentError < Error
    end

    def initialize(api_key, staging_app_name, production_app_name)
      @heroku = PlatformAPI.connect(api_key)
      @heroku_no_cache = PlatformAPI.connect(api_key, cache: Moneta.new(:Null))
      @staging_app_name = staging_app_name
      @production_app_name = production_app_name
      @promoted_release_regexp = /Promote #{@staging_app_name} (v\d+)/
    end

    def get_staging_commit(release)
      @heroku.slug.info(@staging_app_name, release['slug']['id'])['commit']
    end

    def get_production_commit(release)
      @heroku.slug.info(@production_app_name, release['slug']['id'])['commit']
    end

    def current_production_release
      get_releases(@production_app_name)[-1]
    end

    def last_promoted_production_release
      get_releases(@production_app_name).reverse.detect{|release| promoted_from_staging?(release)} or raise Error.new "Can't find a production release that was promoted from staging!"
    end

    def staging_release_name(production_release)
      unless production_release['description'] =~ @promoted_release_regexp
        raise Error.new "Production release was not promoted from staging: #{production_release['description']}"
      end
      $1
    end

    def promoted_from_staging?(release)
      release['description'] =~ @promoted_release_regexp
    end

    def staging_releases_since(staging_release_name)
      staging_releases = get_releases(@staging_app_name)
      index = staging_releases.index { |release| release['name'] == staging_release_name }
      if index.nil?
        raise Error.new "Could not find staging release #{staging_release_name}"
      end
      staging_releases.slice(index+1, staging_releases.length)
    end

    def deploy_to_production(staging_release_name, options={})
      slug = staging_slug(staging_release_name)
      puts "Deploying slug to production: #{slug}"
      unless options[:dry_run]
        @heroku.release.create(@production_app_name, {'slug' => slug, 'description' => "Promote #{@staging_app_name} #{staging_release_name}"})
        db_migrate_on_production(options)
      end
    end

    def staging_slug(staging_release_name)
      unless staging_release_name =~ /\Av(\d+)\z/
        raise Error.new "Unexpected release name: #{staging_release_name}"
      end
      result = @heroku.release.info(@staging_app_name, $1)
      result['slug']['id'] || raise(Error.new("Could not find slug in API response: #{result.inspect}"))
    end

    def db_migrate_on_production(options={}, attempts=0)
      begin
        tasks = %w(db:migrate db:seed) + Array(options[:rake])
        heroku_run @production_app_name, "rake #{tasks.join(' ')}"
      rescue => e
        if attempts < 2
          db_migrate_on_production(options, attempts+1)
          raise PostDeploymentError if attempts == 0
        else
          raise e
        end
      end
    end

  private
    def get_releases(app_name)
      # Use our own cache because of https://github.com/heroku/platform-api/issues/16
      @release_cache ||= {}
      @release_cache[app_name] ||= @heroku_no_cache.release.list(app_name).to_a
    end

    def heroku_run(app_name, command)
      puts "Running command on #{app_name}: #{command}..."
      data = @heroku.dyno.create(app_name, { command: command, attach: true })
      read, write = IO.pipe
      Rendezvous.start(url: data['rendezvous_url'], input: read)
      read.close
      write.close
      puts "Done."
    end
  end
end
