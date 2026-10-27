require File.expand_path('lib/foreman_google/version', __dir__)

Gem::Specification.new do |s|
  s.name        = 'foreman_google'
  s.version     = ForemanGoogle::VERSION
  s.metadata    = { 'is_foreman_plugin' => 'true',
'rubygems_mfa_required' => 'true' }
  s.license     = 'GPL-3.0'
  s.authors     = ['The Foreman Team']
  s.email       = ['dev@community.theforeman.org']
  s.homepage    = 'https://github.com/theforeman/foreman_google'
  s.summary     = 'Google Compute Engine plugin for the Foreman'
  s.description = 'Google Compute Engine plugin for the Foreman'
  s.required_ruby_version = '>= 3.0', '< 4'

  s.files = Dir['{app,config,db,lib,locale,webpack}/**/*'] + ['LICENSE', 'Rakefile', 'README.md', 'package.json']
  s.test_files = Dir['test/**/*'] + Dir['webpack/**/__tests__/*.js']

  # Use the newest google-cloud-compute line that still works with Ruby 3.0,
  # which remains the safe baseline for EL9 packaging.
  s.add_dependency 'google-cloud-compute', '1.15.0'
  # Keep the versioned client below 2.22.0 so resolution stays within the
  # Ruby-3.0-compatible line even when the builder runs a newer Ruby.
  s.add_dependency 'google-cloud-compute-v1', '>= 2.15.0', '< 2.22.0'
  # Keep protobuf pinned to the last known version before DescriptorPool#build
  # compatibility issues were reported with older generated clients.
  s.add_dependency 'google-protobuf', '3.25.4'
end
