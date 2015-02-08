require_relative 'redis_pool'

module LionAttr
  class InternalRedis
    def initialize(hash_name)
      @hash_name = hash_name
    end

    def get(key)
      redis.with { |c| c.hget @hash_name, key }
    end

    def set(key, value)
      redis.with { |c| c.hset @hash_name, key, value }
    end

    def exists(key)
      redis.with { |c| c.hexists @hash_name, key }
    end

    def del(key)
      redis.with { |c| c.hdel @hash_name, key }
    end

    def setnx(key, value)
      redis.with { |c| c.hsetnx @hash_name, key, value }
    end


    def incrby(key, increment)
      redis.with { |c| c.hincrby @hash_name, key, increment }
    end

    def incrbyfloat(key, increment)
      redis.with { |c| c.hincrbyfloat @hash_name, key, increment }
    end

    def mget(keys)
      redis.with { |c| c.hmget @hash_name, keys }
    end

    def redis
      RedisPool.instance
    end
  end
end
