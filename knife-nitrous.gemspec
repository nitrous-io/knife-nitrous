# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'knife-nitrous/version'

Gem::Specification.new do |gem|
  gem.name          = "knife-nitrous"
  gem.version       = KnifeNitrous::VERSION
  gem.authors       = ["Arun Thampi"]
  gem.email         = ["arun@nitrous.io"]
  gem.description   = %q{Knife plugin that allows you to create/provision Nitrous.IO servers on EC2 using Chef-Solo}
  gem.summary       = %q{Knife plugin that allows you to create/provision Nitrous.IO servers on EC2 using Chef-Solo}
  gem.homepage      = "https://www.nitrous.io"

  gem.add_dependency  "fog",            "~> 1.18.0"
  gem.add_dependency  "domainatrix",    "~> 0.0.11"
  gem.add_dependency  "activesupport",  "~> 3.2.8"
  gem.add_dependency  "ipaddress",      "~> 0.8.0"

  gem.add_dependency  "knife-solo",           "~> 0.4.0"
  gem.add_dependency  "knife-solo_data_bag",  "~> 0.4.0"
  gem.add_dependency  "droplet_kit",          "~> 1.1.3"
  gem.add_dependency  "slack-notifier",       "~> 1.0.0"
  gem.add_dependency  "app_conf",             "~> 0.4.2"

  gem.add_development_dependency  "chef",     "~> 11.6.0"
  gem.add_development_dependency  "rspec",    "~> 2.12.0"
  gem.add_development_dependency  "fakefs",   "~> 0.4.2"
  gem.add_development_dependency  "rake"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
