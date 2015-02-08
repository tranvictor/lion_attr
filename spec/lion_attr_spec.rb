require 'spec_helper'

class TestRedis
  include Mongoid::Document
  field :foo, type: Integer
  field :bar, type: Integer
  field :mew, type: Float
  field :baz, type: Float
  field :qux, type: String
  include LionAttr
  live :foo, :bar, :mew, :qux
end

describe LionAttr do
  before(:each) do
    @test = TestRedis.new
    @redis = LionAttr::InternalRedis.new(@test.class.name)
  end

  describe "class#incr" do
    before(:each) do
      @test.save
    end

    it 'defines an incr method on the class' do
      expect(@test.class).to respond_to(:incr)
    end

    it 'should change attribute value in redis' do
      @test.foo = 0
      @redis.set(@test.key(:foo), 0)
      expect(@redis.get(@test.key(:foo))).to eq(@test.foo.to_s)
      TestRedis.incr(@test.id, :foo, 10)
      expect(@redis.get(@test.key(:foo))).not_to eq((@test.foo + 10).to_s)
    end

    it 'should work fine if the attribute is not initialized to redis yet' do
      @test.foo = 50
      @test.save
      TestRedis.incr @test.id, :foo, 1
      expect(@test.foo).to eq 51
    end

    it 'should not be affected by fetch' do
      @test.foo = 0
      @test.save
      @test.incr :foo, 10
      @new_test = TestRedis.fetch(@test.id)
      TestRedis.incr @test.id, :foo, 10
      expect(@new_test.foo).to eq 20
    end

    it 'should return attribute value in redis' do
      expect(TestRedis.incr(@test.id, :foo,
                            10).to_s).to eq(@redis.get(@test.key(:foo)))
    end

    it 'should rescue error by return error message' do
      #increase integer field by float increment
      err_msg = "ERR value is not an integer or out of range"
      expect(TestRedis.incr(@test.id, :foo, 10.0)).to eq(err_msg)

      #increase float field by string
      err_msg = 'ERR value is not a valid float'
      expect(TestRedis.incr(@test.id, :mew, 'a')).to eq(err_msg)

      #increase string field
      err_msg = 'ERR hash value is not a number'
      expect(TestRedis.incr(@test.id, :qux, 10)).to eq(err_msg)
    end

    it 'should set default value for increment is 1' do
      @redis.set(@test.key(:foo), 0)
      TestRedis.incr @test.id, :foo
      expect(@redis.get(@test.key(:foo))).to eq(1.to_s)
    end

    it 'should raise exception when incr not live attribute' do
      err_msg = 'baz is not a live attributes'
      expect(@test.incr(:baz)).to eq(err_msg)
    end
  end

  describe 'more methods' do
    it 'should generate method to fetch attributes value from cache' do
      expect(@test).to respond_to(:foo)
      expect(@test).to respond_to(:foo=)
      expect(@test).to respond_to(:bar)
      expect(@test).to respond_to(:bar=)
      expect(@test).to respond_to(:update_db)
      expect(@test).to respond_to(:incr)
      expect(@test.class).to respond_to(:fetch)
      expect(@test.class).to respond_to(:live_fields)
    end
  end

  describe 'callback' do
    it 'should set callback function' do
      expect(@test).to receive(:clean_cache_after_destroy)
      @test.destroy
    end

    it 'should remove live attribute in redis if object was destroy' do
      @redis.set(@test.key(:foo), 10)
      @redis.set(@test.key(:bar), 10)
      @test.destroy
      expect(@redis.get(@test.key(:foo))).to eq(nil)
      expect(@redis.get(@test.key(:bar))).to eq(nil)
    end

    it 'should remove object in redis if object was destroyed' do
      id = @test.id
      @test.save
      @test.class.fetch(id)
      expect(@redis.get(id)).to eq(@test.as_document.to_json)
      @test.destroy
      expect(@redis.get(id)).to eq(nil)
    end
  end

  describe '#fetch' do
    it 'should return object if it exist in redis' do
      @redis.set(@test.id, @test.as_document.to_json)
      expect(@test.class.fetch(@test.id)).to eq(@test)
    end

    it 'should set object in to redis in case not exist in redis yet' do
      id = @test.id
      expect(@redis.get(id)).to eq(nil)
      @test.save
      @test.class.fetch(id)
      expect(@redis.get(id)).to eq(@test.as_document.to_json)
    end

    it 'should return updated object if original was updated' do
      @test.save
      @old_test = TestRedis.fetch(@test.id)
      @test.update(:baz => 100)
      @updated_test = TestRedis.fetch(@test.id)
      expect(@updated_test.baz).to eq 100
    end

    it 'should be ok if the model is changed while cached object
    is still available, it will refetch from db if the cached version is invalid' do
      @test.save
      document = @test.as_document
      document['will_be_removed'] = 10
      json_data = document.to_json
      @redis.set(@test.id, json_data)
      expect { @new_test = TestRedis.fetch(@test.id) }.not_to raise_error
    end
  end

  describe '#key' do
    it 'should contain object id and field name' do
      expect(@test.key(:foo)).to eq("#{@test.id}_foo")
      puts @test.key(:foo)
    end
  end

  describe '#update_db' do
    it 'should update mongodb record if attribute value
    is difference from redis' do
      @test.incr(:foo, 10)
      expect(@redis.get(@test.key(:foo))).not_to eq(@test.read_attribute(:foo).to_s)
      @test.update_db
      expect(@redis.get(@test.key(:foo))).to eq(@test.read_attribute(:foo).to_s)
    end
  end

  describe 'live attributes' do
    it 'can be called multiple times' do
      class TestMultipleLive
        include Mongoid::Document
        include LionAttr
        field :foo, type: Integer
        live :foo
        field :bar, type: Integer
        live :bar
        include LionAttr
      end
      expect(TestMultipleLive.live_fields).to include(:foo, :bar)
      @test = TestMultipleLive.new
      expect(@test).to receive(:update_to_redis).exactly(1).times
      @test.save
    end

    context 'custom key' do
      it 'has default key of :id but can be assigned to other field' do
        class TestCustomKey
          include Mongoid::Document
          include LionAttr
          field :foo, type: Integer
          live :bar
        end
        expect(TestCustomKey.live_key).to eq :id
        TestCustomKey.class_eval do
          self.live_key = :bar
        end
        expect(TestCustomKey.live_key).to eq :bar
      end

      it 'should change the key to save to redis' do
        class TestCustomKey1
          include Mongoid::Document
          include LionAttr
          field :foo, type: Integer
          field :bar
          live :bar
          self.live_key = :foo
        end
        @instance = TestCustomKey1.new :foo => 100
        expect(@instance.key(:bar)).to eq "100_bar"
      end
    end

    describe '#incr' do
      it 'should change attribute value in redis' do
        @test.foo = 0
        @redis.set(@test.key(:foo), 0)
        expect(@redis.get(@test.key(:foo))).to eq(@test.foo.to_s)
        @test.incr(:foo, 10)
        expect(@redis.get(@test.key(:foo))).not_to eq((@test.foo + 10).to_s)
      end

      it 'should work fine if the attribute is not initialized to redis yet' do
        @test.foo = 50
        @test.save
        @test.incr :foo, 1
        expect(@test.foo).to eq 51
      end

      it 'should not be affected by fetch' do
        @test.foo = 0
        @test.save
        @test.incr :foo, 10
        @new_test = TestRedis.fetch(@test.id)
        @new_test.incr :foo, 10
        expect(@new_test.foo).to eq 20
      end

      it 'should return attribute value in redis' do
        expect(@test.incr(:foo, 10).to_s).to eq(@redis.get(@test.key(:foo)))
      end

      it 'should rescue error by return error message' do
        #increase integer field by float increment
        err_msg = "ERR value is not an integer or out of range"
        expect(@test.incr(:foo, 10.0)).to eq(err_msg)

        #increase float field by string
        err_msg = 'ERR value is not a valid float'
        expect(@test.incr(:mew, 'a')).to eq(err_msg)

        #increase string field
        err_msg = 'ERR hash value is not a number'
        expect(@test.incr(:qux, 10)).to eq(err_msg)
      end

      it 'should set default value for increment is 1' do
        @redis.set(@test.key(:foo), 0)
        @test.incr(:foo)
        expect(@redis.get(@test.key(:foo))).to eq(1.to_s)
      end

      it 'should raise exception when incr not live attribute' do
        err_msg = 'baz is not a live attributes'
        expect(@test.incr(:baz)).to eq(err_msg)
      end
    end

    describe '#getter' do
      it 'should read attribute value from db
      in case the value is not exist in redis' do
        # redis not contain attribute value
        expect(@redis.get(@test.key(:foo))).to eq(nil)
        # fetch cache still return attribute value
        expect(@test.foo).to eq(@test.read_attribute(:foo))
        # redis should contain attribute value now
        expect(@redis.get(@test.key(:foo))).to eq(@test.foo.to_s)
      end

      it 'should return attribute value from redis if it exist in redis' do
        @test.foo = 10
        @redis.set(@test.key(:foo), 20)
        expect(@test.foo).to eq(20)
      end
    end
  end
end
