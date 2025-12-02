# MemRedisStore

A Rails cache store that combines `MemoryStore` (L1 cache) and `RedisCacheStore` (L2 cache) for optimal performance.

## Requirements

- Ruby 2.7.4+
- Rails 6.0+

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mem_redis_store'
```

And then execute:

```bash
bundle install
```

## Configuration

In your Rails application configuration (e.g., `config/environments/production.rb`):

```ruby
config.cache_store = :mem_redis_store, {
  redis_cache_store: {
    url: ENV['REDIS_URL'],
    pool_size: 5,
    pool_timeout: 5,
    expires_in: 1.hour
  },
  memory_store: {
    size: 32.megabytes
  }
}
```

## Usage

### Reading from cache

**Read from Redis only (default behavior):**
```ruby
Rails.cache.read('test_key')
```

**Read from memory first, fallback to Redis:**
```ruby
Rails.cache.read('test_key', use_memory: true)
```
- Checks memory store first
- If not found, reads from Redis
- If found in Redis, writes to memory store
- Returns the value

**Read with custom memory expiration:**
```ruby
Rails.cache.read('test_key', use_memory: true, memory_expires_in: 1.minute)
```
- Same as above, but when writing to memory store, sets expiration to 1 minute

### Writing to cache

**Write to Redis only (default behavior):**
```ruby
Rails.cache.write('test_key', 'test_val')
```

**Write to both Redis and memory:**
```ruby
Rails.cache.write('test_key', 'test_val', use_memory: true)
```

**Write with custom memory expiration:**
```ruby
Rails.cache.write('test_key', 'test_val', use_memory: true, memory_expires_in: 1.minute)
```
- Writes to Redis with default expiration
- Writes to memory store with 1 minute expiration

### Fetching from cache

**Fetch from Redis only (default behavior):**
```ruby
Rails.cache.fetch('test_key') { 'test_val' }
```

**Fetch from memory first, fallback to Redis:**
```ruby
Rails.cache.fetch('test_key', use_memory: true) { 'test_val' }
```
- Checks memory store first
- If not found, fetches from Redis (runs block if not in Redis)
- Writes result to memory store
- Returns the value

**Fetch with custom memory expiration:**
```ruby
Rails.cache.fetch('test_key', use_memory: true, memory_expires_in: 1.minute) { 'test_val' }
```

### Other operations

All standard cache operations are supported:

```ruby
# Delete from both stores
Rails.cache.delete('test_key')

# Check existence (checks Redis)
Rails.cache.exist?('test_key')

# Clear both stores
Rails.cache.clear

# Increment/decrement (Redis only)
Rails.cache.increment('counter')
Rails.cache.decrement('counter')
```

## How it works

- **Redis** is always the source of truth (L2 cache)
- **Memory store** acts as a fast L1 cache when `use_memory: true` is specified
- Read path with `use_memory: true`:
  1. Check memory store
  2. If miss, check Redis
  3. If found in Redis, populate memory store
  4. Return value
- Write path with `use_memory: true`:
  1. Write to Redis
  2. Write to memory store

## License

The gem is available as open source under the terms of the MIT License.
