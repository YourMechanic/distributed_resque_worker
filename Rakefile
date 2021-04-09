# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'resque'
require 'resque/tasks'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task 'resque:setup' do
  require_relative 'lib/distributed_resque_worker'
end

task default: %i[spec rubocop resque]
