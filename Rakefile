require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'

namespace :test do
  Rake::TestTask.new(:all) do |t|
    t.libs << "test"
    t.pattern = 'test/**/*_test.rb'
    t.verbose = true
  end
end
