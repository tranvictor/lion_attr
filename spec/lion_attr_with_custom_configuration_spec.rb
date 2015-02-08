require 'spec_helper'

describe LionAttr do

  describe "configuration" do
    it "can be configured to specific redis config" do
      LionAttr.configure do |config|
        puts "setting configuration"
        config.redis_config = { :db => 13 }
      end

      class TestClass
        include Mongoid::Document
        include LionAttr
        field :foo, type: Integer

        live :foo
      end

      @test = TestClass.new
      @test.save
      redis = Redis.new :db => 13
      expect(redis.exists "TestClass").to be true
    end
  end
end
