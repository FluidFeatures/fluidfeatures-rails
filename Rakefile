require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'

task :test do
  Dir.chdir("test/testapp") do
    exec("rspec")
  end
end
