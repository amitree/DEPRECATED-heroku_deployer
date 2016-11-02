Gem::Specification.new do |s|
  s.name        = 'heroku_deployer'
  s.version     = '0.7.17'
  s.date        = Date.today.to_s
  s.summary     = "Heroku Deployer"
  s.description = "Gem that handles automatic deployment of code to Heroku, integrating with Pivotal Tracker and Git"
  s.authors     = ["Nick Wargnier", "Tony Novak"]
  s.email       = 'engineering@amitree.com'
  s.files       = Dir.glob('lib/**/*.rb')

  s.homepage    = 'http://rubygems.org/gems/heroku_deployer'
  s.license     = 'MIT'

  s.required_ruby_version = '~> 2.0'
  s.add_development_dependency 'rspec', '>= 2.14.1'
  s.add_runtime_dependency 'octokit', '>= 2.7.1'
  s.add_runtime_dependency 'platform-api', '>= 0.2.0'
  s.add_runtime_dependency 'rendezvous', '>= 0.0.2'

  s.add_runtime_dependency 'pivotal-tracker', '>= 0.5.13'
end
