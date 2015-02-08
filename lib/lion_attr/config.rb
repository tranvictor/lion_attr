# encoding: utf-8

module LionAttr

  # This module defines all the configuration options for LionAttr
  module Config
    def redis_config=(options)
      @redis_config = options
      RedisPool.instance.update_pool
    end

    def redis_config
      @redis_config ||= {}
    end

    extend self
  end

  module ModuleInterface
    # Sets the LionAttr configuration options. Best used by passing a block.
    # You should configure before actually using LionAttr.
    #
    # @example Set up configuration options and tell LionAttr to store everything in
    # redis datababse 13
    #
    #   LionAttr.configure do |config|
    #     config.redis_config = { db: 13 }
    #   end
    #
    # @return [ Config ] The configuration object.
    #
    # @since 0.1.0
    def configure
      block_given? ? yield(::LionAttr::Config) : ::LionAttr::Config
    end
  end
  extend ModuleInterface
end
