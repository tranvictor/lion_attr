# encoding: utf-8
require 'bundler/setup'
Bundler.setup

require 'mongoid'

Mongoid.load!("#{File.dirname(__FILE__)}/mongoid.yml", :test)

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

require 'lion_attr'

RSpec.configure do |config|
  config.order = :random

  config.color = true

  config.tty = true

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = :expect
  end
end
