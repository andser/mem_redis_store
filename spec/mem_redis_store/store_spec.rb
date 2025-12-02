# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemRedisStore::Store do
  let(:mock_redis) { MockRedis.new }
  let(:store) do
    described_class.new(
      redis_cache_store: { redis: mock_redis },
      memory_store: { size: 32.megabytes }
    )
  end

  describe '#initialize' do
    it 'creates a store with redis and memory backends' do
      expect(store).to be_a(ActiveSupport::Cache::Store)
    end

    it 'accepts redis_cache_store options' do
      custom_store = described_class.new(
        redis_cache_store: { redis: mock_redis, namespace: 'test' }
      )
      expect(custom_store).to be_a(described_class)
    end

    it 'accepts memory_store options' do
      custom_store = described_class.new(
        memory_store: { size: 64.megabytes }
      )
      expect(custom_store).to be_a(described_class)
    end
  end

  describe '#read' do
    context 'without use_memory option' do
      it 'reads from redis only' do
        store.write('key1', 'value1')
        expect(store.read('key1')).to eq('value1')
      end

      it 'returns nil when key does not exist' do
        expect(store.read('nonexistent')).to be_nil
      end
    end

    context 'with use_memory: true' do
      it 'reads from memory store first if value exists' do
        store.write('key1', 'value1', use_memory: true)

        # Clear redis to verify it reads from memory
        mock_redis.flushdb

        expect(store.read('key1', use_memory: true)).to eq('value1')
      end

      it 'falls back to redis if not in memory' do
        store.write('key1', 'value1')

        result = store.read('key1', use_memory: true)

        expect(result).to eq('value1')
      end

      it 'writes to memory store when reading from redis' do
        store.write('key1', 'value1')

        # First read should get from redis and populate memory
        store.read('key1', use_memory: true)

        # Clear redis
        mock_redis.flushdb

        # Second read should get from memory
        expect(store.read('key1', use_memory: true)).to eq('value1')
      end

      it 'returns nil when key does not exist in either store' do
        expect(store.read('nonexistent', use_memory: true)).to be_nil
      end
    end

    context 'with use_memory: true and memory_expires_in' do
      it 'writes to memory with custom expiration' do
        store.write('key1', 'value1')

        store.read('key1', use_memory: true, memory_expires_in: 60)

        # Clear redis
        mock_redis.flushdb

        # Should still be in memory
        expect(store.read('key1', use_memory: true)).to eq('value1')
      end
    end
  end

  describe '#write' do
    context 'without use_memory option' do
      it 'writes to redis only' do
        expect(store.write('key1', 'value1')).to be_truthy
        expect(store.read('key1')).to eq('value1')
      end

      it 'does not write to memory store' do
        store.write('key1', 'value1')

        # Clear redis
        mock_redis.flushdb

        # Should not be in memory
        expect(store.read('key1', use_memory: true)).to be_nil
      end
    end

    context 'with use_memory: true' do
      it 'writes to both redis and memory' do
        store.write('key1', 'value1', use_memory: true)

        # Clear redis
        mock_redis.flushdb

        # Should still be in memory
        expect(store.read('key1', use_memory: true)).to eq('value1')
      end
    end

    context 'with use_memory: true and memory_expires_in' do
      it 'writes to memory with custom expiration' do
        store.write('key1', 'value1', use_memory: true, memory_expires_in: 60)

        # Clear redis
        mock_redis.flushdb

        # Should still be in memory
        expect(store.read('key1', use_memory: true)).to eq('value1')
      end
    end

    context 'with expires_in option' do
      it 'sets expiration on redis' do
        store.write('key1', 'value1', expires_in: 60)
        expect(store.read('key1')).to eq('value1')
      end
    end
  end

  describe '#fetch' do
    context 'without use_memory option' do
      it 'fetches from redis' do
        result = store.fetch('key1') { 'computed_value' }
        expect(result).to eq('computed_value')
        expect(store.read('key1')).to eq('computed_value')
      end

      it 'returns existing value without executing block' do
        store.write('key1', 'existing_value')

        result = store.fetch('key1') { 'new_value' }

        expect(result).to eq('existing_value')
      end

      it 'does not write to memory store' do
        store.fetch('key1') { 'value1' }

        # Clear redis
        mock_redis.flushdb

        # Should not be in memory
        expect(store.read('key1', use_memory: true)).to be_nil
      end
    end

    context 'with use_memory: true' do
      it 'checks memory store first' do
        store.write('key1', 'value1', use_memory: true)

        # Clear redis to verify it reads from memory
        mock_redis.flushdb

        result = store.fetch('key1', use_memory: true) { 'new_value' }

        expect(result).to eq('value1')
      end

      it 'falls back to redis if not in memory' do
        store.write('key1', 'value1')

        result = store.fetch('key1', use_memory: true) { 'new_value' }

        expect(result).to eq('value1')
      end

      it 'writes to memory when fetching from redis' do
        store.write('key1', 'value1')

        # First fetch should get from redis and populate memory
        store.fetch('key1', use_memory: true) { 'new_value' }

        # Clear redis
        mock_redis.flushdb

        # Second fetch should get from memory
        result = store.fetch('key1', use_memory: true) { 'newer_value' }
        expect(result).to eq('value1')
      end

      it 'executes block and writes to both stores if key does not exist' do
        result = store.fetch('key1', use_memory: true) { 'computed_value' }

        expect(result).to eq('computed_value')

        # Clear redis
        mock_redis.flushdb

        # Should be in memory
        expect(store.read('key1', use_memory: true)).to eq('computed_value')
      end
    end

    context 'with use_memory: true and memory_expires_in' do
      it 'writes to memory with custom expiration when fetching from redis' do
        store.write('key1', 'value1')

        store.fetch('key1', use_memory: true, memory_expires_in: 60) { 'new_value' }

        # Clear redis
        mock_redis.flushdb

        # Should still be in memory
        expect(store.read('key1', use_memory: true)).to eq('value1')
      end
    end
  end

  describe '#delete' do
    it 'deletes from both redis and memory' do
      store.write('key1', 'value1', use_memory: true)

      store.delete('key1')

      expect(store.read('key1')).to be_nil
      expect(store.read('key1', use_memory: true)).to be_nil
    end
  end

  describe '#exist?' do
    it 'checks if key exists in redis' do
      store.write('key1', 'value1')
      expect(store.exist?('key1')).to be true
    end

    it 'returns false for non-existent keys' do
      expect(store.exist?('nonexistent')).to be false
    end
  end

  describe '#clear' do
    it 'clears both redis and memory stores' do
      store.write('key1', 'value1', use_memory: true)
      store.write('key2', 'value2', use_memory: true)

      store.clear

      expect(store.read('key1')).to be_nil
      expect(store.read('key2')).to be_nil
      expect(store.read('key1', use_memory: true)).to be_nil
      expect(store.read('key2', use_memory: true)).to be_nil
    end
  end

  describe '#increment' do
    it 'increments counter in redis' do
      store.write('counter', 1, raw: true)
      store.increment('counter')
      expect(store.read('counter', raw: true).to_i).to eq(2)
    end

    it 'increments by specified amount' do
      store.write('counter', 1, raw: true)
      store.increment('counter', 5)
      expect(store.read('counter', raw: true).to_i).to eq(6)
    end
  end

  describe '#decrement' do
    it 'decrements counter in redis' do
      store.write('counter', 10, raw: true)
      store.decrement('counter')
      expect(store.read('counter', raw: true).to_i).to eq(9)
    end

    it 'decrements by specified amount' do
      store.write('counter', 10, raw: true)
      store.decrement('counter', 3)
      expect(store.read('counter', raw: true).to_i).to eq(7)
    end
  end

  describe '#delete_matched' do
    it 'deletes matching keys from both stores' do
      store.write('test:1', 'value1', use_memory: true)
      store.write('test:2', 'value2', use_memory: true)
      store.write('other:1', 'value3', use_memory: true)

      store.delete_matched('test:*')

      expect(store.read('test:1')).to be_nil
      expect(store.read('test:2')).to be_nil
      expect(store.read('other:1')).to eq('value3')
    end
  end

  describe '#cleanup' do
    it 'calls cleanup on both stores' do
      expect { store.cleanup }.not_to raise_error
    end
  end
end
