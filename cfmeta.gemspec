# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "cfmeta/version"

Gem::Specification.new do |s|
  s.name        = "cfmeta"
  s.version     = Cfmeta::VERSION
  s.authors     = ["Dave McCrory"]
  s.email       = ["dave@mccrory.me"]
  s.homepage    = "http://github.com/mccrory"
  s.summary     = %q{Cloud Foundry Metaprogramming Client}
  s.description = %q{Wraps the Cloud Foundry vmc client to make it easy to create Metaprogrammable Apps}

  s.rubyforge_project = "cfmeta"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  s.add_dependency('json', "~> 1.6.0")
  s.add_dependency('zip', "~> 2.0.2")
  s.add_dependency('vmc', "~> 0.3.12")
end
