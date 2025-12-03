# frozen_string_literal: true

require_relative 'lib/mem_redis_store/version'

Gem::Specification.new do |spec|
  spec.name          = 'mem_redis_store'
  spec.version       = MemRedisStore::VERSION
  spec.authors       = ['Your Name']
  spec.email         = ['your.email@example.com']

  spec.summary       = 'A Rails cache store that combines MemoryStore and RedisCacheStore'
  spec.description   = 'MemRedisStore provides a two-tier caching solution with MemoryStore as L1 cache and RedisCacheStore as L2 cache'
  spec.homepage      = 'https://github.com/yourusername/mem_redis_store'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.4'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  spec.files = Dir['lib/**/*', 'README.md', 'LICENSE.txt']
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport', '~> 6.0'
  spec.add_dependency 'redis', '>= 4.0'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'mock_redis', '~> 0.30'
end
