# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'distributed_resque_worker/version'

Gem::Specification.new do |spec|
  spec.name          = 'distributed_resque_worker'
  spec.version       = DistributedResqueWorker::VERSION
  spec.authors       = ['TruptiHosmani']
  spec.email         = ['trupti@yourmechanic.com']

  spec.summary       = 'Gem for downloadable reports using Resque'
  spec.description   = 'Downloadable reports which uses background workers'\
                       'and then emails an S3 link for CSV to the requestor'
  spec.homepage      = 'https://github.com/YourMechanic/distributed_resque_worker'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3')
  spec.metadata['allowed_push_host'] = 'https://github.com/YourMechanic/distributed_resque_worker'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/YourMechanic/distributed_resque_worker'

  # Specify which files should be added to the gem when it is released.
  # `git ls-files -z` loads the files in RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{\A(?:test|spec|features)/})
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.17.3'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.48'
  spec.add_development_dependency 'webmock'
  spec.add_dependency 'aws-sdk', '1.11.1'
  spec.add_dependency 'resque', '~> 2.0'
end
