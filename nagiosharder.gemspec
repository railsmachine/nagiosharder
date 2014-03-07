# encoding: utf-8
$:.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'nagiosharder'
  s.version     = '0.5.0'
  s.date        = Time.now.strftime('%Y-%m-%d')
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Josh Nichols', 'Jesse Newland', 'Travis Graham']
  s.email       = ['josh@technicalpickles.com', 'jesse@github.com', 'travis@railsmachine.com']
  s.homepage    = 'http://github.com/railsmachine/nagiosharder'
  s.summary     = %q{Nagios access at your ruby fingertips}
  s.description = %q{Nagios access at your ruby fingertips}

  s.rubyforge_project = 'nagiosharder'

  s.add_dependency 'rest-client'
  s.add_dependency 'nokogiri'
  s.add_dependency 'activesupport'
  s.add_dependency 'i18n'
  s.add_dependency 'terminal-table'
  s.add_dependency 'httparty'
  s.add_dependency 'hashie', '~> 1.2.0'
  s.add_development_dependency 'rspec', '>= 1.2.9'
  s.add_development_dependency 'webmock'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = ['nagiosharder']
  s.require_paths = ['lib']
end
