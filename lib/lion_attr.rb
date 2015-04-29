require_relative 'lion_attr/internal_redis'
require_relative 'lion_attr/config'
require_relative 'lion_attr/bson'

# LionAttr, a gem to store Mongoid object in Redis for fast access. It also helps
# you to store object attributes to real time update via Redis increamental
# operations.
#
# In many web applications, updating objects to database (mongodb) too often
# would hurt overal application performance because databases usually need to
# do some extra tasks such as indexing, updating its cache ...
#
# One of the most popular example for this problem is tracking pageview of a web
# page. Imagine if you have a blog and you want to know how many time people visit
# a specific article, what would you do? An obvious way to do so is whenever a
# person make a request, you increase the record holding pageview counter by using
# `mongoid#inc` method. Doing this is not a good idea because it increases database
# calls making your application slower.
#
# A better solution for this problem is to keep the pageview counter in memory
# (which is fast) key-value storage such as Redis. Instead of increasing the
# counter by the database, we increase the counter inside Redis and save back to
# the database later (like after 10 mins, 30 mins or even a day).
#
# LionAttr provides APIs for you to do so with ease.
#
# That counter is usually an attribute of a Model object, the difference is that
# attribute will get the value from Redis instead of the database. We call it live
# attribute because it tends update its value very frequently.
#
# @example
#
#  class Article
#    include Mongoid::Document
#    include LionAttr
#    field :url, type: String
#    field :view, type: Integer
#
#    # field :view will be stored in Redis and saved back to Mongodb later
#    live :view
#  end
#
# @todo: Cache object
# @todo:       Custom key
# @todo: Inc
# @todo: Callbacks
# @todo: Configure
#
# @since 0.1.0
#
# @see http://tranvictor.github.io/lion_attr

module LionAttr

  # Including LionAttr will set an after save callback to update the object cache
  # in Redis.
  #
  # @param base Mongoid::Document
  def self.included(base)
    base.extend(ClassMethods)
    base.set_callback(:save, :after, :update_to_redis, prepend: true)
  end

  # Key to store in Redis, it is combined by object identity and field name.
  #
  # @param [String, Symbol] field
  # @return [String]
  # @example
  #   article.key(:view)
  #   #=> 54d5f10d5675730bd1050000_view
  #
  #   article.url = "http://clicklion.com/article/1"
  #   article.class.live_key = :url
  #   article.key(:view)
  #   #=> http://clicklion.com/article/1_view
  #
  # @see ClassMethods#live_key Object Identity definition
  def key(field)
    self.class._key(self.send(self.class.live_key), field)
  end

  # Call this method to manually create a cache of the object in Redis.
  # It will store the object as a json string in a Redis Hash with key is the
  # object's id. Object from different classes will be stored in different hashes
  # distinguished by class full name.
  #
  # @see InternalRedis
  def update_to_redis
    InternalRedis.new(self.class.name).set(id, as_document.to_json)
  end

  # Call this method will clear all of Redis keys related to the object.
  def clean_cache_after_destroy
    @live_keys ||= self.class.live_fields.map { |f| key(f) }
    @internal_redis ||= InternalRedis.new(self.class.name)
    @internal_redis.del @live_keys
    @internal_redis.del id
  end

  module ClassMethods

    # Fetch the object specified with an id from Redis. It will not touch the
    # database (Mongdb). If that object is not available on Redis or invalid (due to
    # model changes, it will make a query to the database (Mongodb).
    #
    # @param [String] id
    # @return [Mongoid::Document]
    def fetch(id)
      @internal_redis ||= InternalRedis.new(name)
      string_object = @internal_redis.get(id)
      if string_object.nil?
        object = _fetch_from_db(id)
      else
        object = new(JSON.load(string_object))
      end
    rescue Mongoid::Errors::UnknownAttribute
      object = _fetch_from_db(id)
    end

    # Query the object by id, and create a cache version in Redis.
    #
    # @param [String] id
    # @return [Mongoid::Document]
    def _fetch_from_db(id)
      object = find(id)
      @internal_redis.set(id, object.as_document.to_json)
      object
    end

    # Get all live fields of the class
    #
    # @example
    #   article.class.live_fields
    #   #=> [:view]
    def live_fields
      @live_fields
    end

    def live(*fields)
      fields.each do |field|
        generate_fetch_cache_method(field)
        # generate_set_cache_method(field)
      end
      generate_update_db_method(fields)
      generate_incr_method
      (@live_fields ||= []).push(*fields)
      set_callback(:destroy, :after, :clean_cache_after_destroy)
    end

    # Specify the field which is used to get storage key for the object.
    #
    # @param [String, Symbole] field
    # @example
    #   article.class.live_key = :url
    #   # Whenever LionAttr need to use object key, it gets from :url
    def live_key=(field)
      @key = field
    end

    # Get object key to interact with Redis. If you don't specify the live_key
    # :id will be used by default.
    def live_key
      @key || :id
    end

    def generate_update_db_method(_fields)
      define_method('update_db') do
        @live_keys ||= self.class.live_fields.map { |f| key(f) }
        @internal_redis ||= InternalRedis.new(self.class.name)
        redis_values = @internal_redis.mget(@live_keys)
        self.class.live_fields.each_with_index do |f, i|
          if read_attribute(f) != redis_values[i]
            write_attribute(f, redis_values[i])
          end
        end
        # TODO: This could be improved by using batch save instead of saving
        # individual document
        save
      end
    end

    def _key(id, field)
      "#{id}_#{field}"
    end

    # Increase live attributes value in Redis. If the live attributes are not
    # Integer nor Float, a String message will be returned. Otherwise, increased
    # value will be returned.
    #
    # @param [String] id
    # @param [String, Symbol] field
    # @param [Integer] increment
    # @param [InternalRedis] internal_redis
    #
    # @return [Integer, Float, String]
    def incr(id, field, increment = 1, internal_redis = nil)
      unless self.live_fields.include?(field)
        fail "#{field} is not a live attributes"
      end
      internal_redis ||= InternalRedis.new(name)
      _incr(_key(id, field), fields[field.to_s].type,
            @internal_redis, increment) do
        find_by(live_key => id).read_attribute(field)
      end
    rescue => e
      e.message
    end

    def _incr(key, type, internal_redis = nil, increment = 1, &block)
      internal_redis ||= InternalRedis.new(name)
      if block && !internal_redis.exists(key)
        internal_redis.setnx key, block.call
      end
      if type == Integer
        internal_redis.incrby(key, increment)
      elsif type == Float
        internal_redis.incrbyfloat(key, increment)
      else
        'ERR hash value is not a number'
      end
    end

    def generate_incr_method
      define_method('incr') do |field, increment = 1|
        begin
          unless self.class.live_fields.include?(field)
            fail "#{field} is not a live attributes"
          end
          @internal_redis ||= InternalRedis.new(self.class.name)
          self.class._incr(key(field),
                           fields[field.to_s].type,
                           @internal_redis,
                           increment) { read_attribute(field) }
        rescue => e
          e.message
        end
      end
    end

    def generate_fetch_cache_method(name)
      re_define_method("#{name}") do
        @internal_redis ||= InternalRedis.new(self.class.name)
        raw = @internal_redis.get(key(name))
        field = fields[name.to_s]
        if raw.nil?
          raw = read_attribute(name)
          if lazy_settable?(field, raw)
            value = write_attribute(name, field.eval_default(self))
          else
            value = field.demongoize(raw)
            attribute_will_change!(name) if value.resizable?
          end

          @internal_redis.set(key(name), raw)
        else
          value = field.demongoize(raw)
        end
        value
      end
    end
  end
end
