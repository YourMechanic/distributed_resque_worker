# distributed_resque_worker
Distributed Background Worker to process a large workload

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/distributed_resque_worker`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'distributed_resque_worker', git: 'https://github.com/YourMechanic/distributed_resque_worker.git', :branch => 'master'
```
And then execute:
    $ bundle install

Add the following in routes.rb
    require 'resque/server'
    mount Resque::Server.new, at: '/resque'


Setup Redis: Add the following in the config/initializers/resque.yml
```
development: localhost:6379
test: localhost:6379
staging: <%= ENV['REDIS_URL'] %>
production: <%= ENV['REDIS_URL'] %>
```

Configure Resque: Add the following in the config/initializers/resque.rb
```
resque_config = YAML.load(File.read(Rails.root.join('config/resque.yml')))
Resque.redis = resque_config[Rails.env]

Resque.logger = Logger.new(Rails.root.join('log', "#{Rails.env}_resque.log"))
Resque.logger.level = Logger::INFO
```

In your Rakefile, or some other file in lib/tasks (ex: lib/tasks/resque.rake), load the resque rake tasks (For Rails 3+):
```
require 'resque/tasks'
task 'resque:setup' => :environment
```

## Usage
Can use the following code to chunk the work and run on 4 workers using DistributedResqueWorker and you also need to add a function that workers will run with their chunk of work
```
class SomeClass
    ...
    def some_method
        opts = {address:'', requestor: 'trupti', emails: [], requested_date: '', ...}
        input = (1..4).to_a

        worker = DistributedResqueWorker::ResqueWorker.new(
            self,
            'bucket_name',
            'root_dir_to_stor_tmp_files'
        )
        worker.chunk_work_and_enqueue(input, __callee__, opts)
    end
    ...

    def self.some_method_chunk(work_chunk, output_filepath, opts = {})
        # some code to work on the work_chunk and add data into output_filepath
    end

    def self.some_method_post(work_chunk, output_filepath, opts = {})
        # some code to either send email/slack message the final file s3 link
    end
end
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/distributed_resque_worker. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the DistributedResqueWorker project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/distributed_resque_worker/blob/master/CODE_OF_CONDUCT.md).
