$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "lion_attr/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "lion-attr"
  s.version     = LionAttr::VERSION
  s.authors     = ["Victor Tran"]
  s.email       = ["vu.tran54@gmail.com"]
  s.homepage    = "http://github.com/tranvictor"
  s.summary     = "Lion Attr gives convenience of caching active model objects and increase counter without touching database."
  s.description = "Lion Attr uses Redis to store active model object in-mem making it fast accessibility. It also gives convenience to manipulate numeric attributes which will be called live attrbutes. With live attributes, you can increase, decrease in real-time without touching database for high performance."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile",
                "README.rdoc"]

  s.test_files = Dir["spec/**/*"]

  # s.add_dependency "rails", "~> 4.1.6"
  s.add_dependency "redis", "~> 3.1.0"
  s.add_dependency "mongoid", "~> 4.0.0"
  s.add_dependency "connection_pool", "~> 2.0"

  s.add_development_dependency "rspec"
end
