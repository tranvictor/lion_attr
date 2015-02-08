require 'singleton'
require 'redis'
require 'connection_pool'

module LionAttr
  class RedisPool
    include Singleton

    def initialize
      update_pool
    end

    def update_pool
      @pool = ConnectionPool.new(size: 100, timeout: 2) do
        puts ::LionAttr.configure.redis_config
        Redis.new ::LionAttr.configure.redis_config
      end
    end

    def with(&block)
      @pool.with(&block)
    end

  end
end
