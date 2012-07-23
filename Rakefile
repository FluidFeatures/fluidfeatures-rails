require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'

task :default => :test

task :test do
  Dir.chdir("test/testapp") do
    exec("bundle exec rspec spec")
  end
end
