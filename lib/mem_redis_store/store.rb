# frozen_string_literal: true

require 'active_support/cache'
require 'active_support/cache/redis_cache_store'
require 'active_support/cache/memory_store'

module MemRedisStore
  class Store < ActiveSupport::Cache::Store
    def initialize(options = {})
      super(options)

      redis_options = options.delete(:redis_cache_store) || {}
      memory_options = options.delete(:memory_store) || {}

      @redis_store = ActiveSupport::Cache::RedisCacheStore.new(**redis_options)
      @memory_store = ActiveSupport::Cache::MemoryStore.new(**memory_options)
    end

    def clear(options = nil)
      @memory_store.clear
      @redis_store.clear
    end

    def cleanup(options = nil)
      @memory_store.cleanup
      # RedisCacheStore doesn't support cleanup, Redis handles expiration automatically
    end

    def increment(name, amount = 1, options = nil)
      options ||= {}
      @redis_store.increment(name, amount, **options)
    end

    def decrement(name, amount = 1, options = nil)
      options ||= {}
      @redis_store.decrement(name, amount, **options)
    end

    def delete_matched(matcher, options = nil)
      @memory_store.delete_matched(matcher, options)
      @redis_store.delete_matched(matcher, options)
    end

    private

    def read_entry(key, **options)
      use_memory = options.delete(:use_memory)
      memory_expires_in = options.delete(:memory_expires_in)

      if use_memory
        # Try to read from memory store first
        entry = @memory_store.send(:read_entry, key, **options)

        if entry.nil?
          # If not in memory, read from Redis
          entry = @redis_store.send(:read_entry, key, **options)

          # If found in Redis, write to memory store
          if entry
            memory_options = options.dup
            memory_options[:expires_in] = memory_expires_in if memory_expires_in
            @memory_store.send(:write_entry, key, entry, **memory_options)
          end
        end

        entry
      else
        # Only use Redis
        @redis_store.send(:read_entry, key, **options)
      end
    end

    def write_entry(key, entry, **options)
      use_memory = options.delete(:use_memory)
      memory_expires_in = options.delete(:memory_expires_in)

      # Always write to Redis
      result = @redis_store.send(:write_entry, key, entry, **options)

      if use_memory
        # Also write to memory store
        memory_options = options.dup
        memory_options[:expires_in] = memory_expires_in if memory_expires_in
        @memory_store.send(:write_entry, key, entry, **memory_options)
      end

      result
    end

    def delete_entry(key, **options)
      @memory_store.send(:delete_entry, key, **options)
      @redis_store.send(:delete_entry, key, **options)
    end
  end
end
