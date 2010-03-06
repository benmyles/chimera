$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

gem 'uuidtools','= 2.1.1'
gem 'activemodel','= 3.0.0.beta'
gem "yajl-ruby", "= 0.7.4"
gem "fast-stemmer", "= 1.0.0"

require 'fast_stemmer'

require 'digest/sha1'
require 'uuidtools'
require 'yajl'
require 'yaml'
require 'active_model'

require 'redis'
require 'typhoeus'
require 'riak_raw'

require "chimera/error"
require "chimera/attributes"
require "chimera/indexes"
require "chimera/geo_indexes"
require "chimera/associations"
require "chimera/redis_objects"
require "chimera/finders"
require "chimera/persistence"
require "chimera/base"

module Chimera
  VERSION = '0.0.3'
end