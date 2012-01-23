# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "nagiosharder"
  s.version     = "0.4.0"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Josh Nichols"]
  s.email       = ["josh@technicalpickles.com"]
  s.homepage    = "http://github.com/railsmachine/nagiosharder"
  s.summary     = %q{Nagios access at your ruby fingertips}
  s.description = %q{Nagios access at your ruby fingertips}

  s.rubyforge_project = "nagiosharder"

  s.add_dependency 'rest-client', '~> 1.6.1'
  s.add_dependency 'nokogiri'
  s.add_dependency 'activesupport'
  s.add_dependency 'i18n'
  s.add_dependency 'terminal-table'
  s.add_dependency 'httparty', '~> 0.6.1'
  s.add_dependency 'hashie', '~> 1.0.0'
  s.add_development_dependency "rspec", ">= 1.2.9"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = ['nagiosharder']
  s.require_paths = ["lib"]
end
