require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "nagiosharder"
    gem.version = "0.3.0"
    gem.summary = %Q{Nagios access at your ruby fingertips}
    gem.description = %Q{Nagios access at your ruby fingertips}
    gem.email = "josh@technicalpickles.com"
    gem.homepage = "http://github.com/railsmachine/nagiosharder"
    gem.authors = ["Joshua Nichols"]
    gem.add_dependency 'rest-client', '~> 1.6.1'
    gem.add_dependency 'nokogiri', '~> 1.4.3'
    gem.add_dependency 'activesupport'
    gem.add_dependency 'httparty', '~> 0.6.1'
    gem.add_dependency 'hashie', '~> 1.0.0'
    gem.add_development_dependency "rspec", ">= 1.2.9"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :spec => :check_dependencies

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "nagiosharder #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
