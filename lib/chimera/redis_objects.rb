module Chimera
  module RedisObjects
    def self.included(base)
      base.send :extend, ClassMethods
      base.send :include, InstanceMethods
    end
    
    module ClassMethods
      def defined_redis_objects
        @defined_redis_objects || {}
      end

      # available types include:
      #   string, set, zset, list, counter
      def redis_object(name, type = :string, extra_opts={})
        @defined_redis_objects ||= {}
        @defined_redis_objects[name.to_sym] = [type, extra_opts]
        define_method("#{name}") do
          @redis_objects ||= {}
          case type
          when :string then
            @redis_objects[name.to_sym] = Chimera::RedisObjectProxy::String.new(self, name, extra_opts)
          when :set then
            @redis_objects[name.to_sym] = Chimera::RedisObjectProxy::Set.new(self, name, extra_opts)
          when :zset then
            @redis_objects[name.to_sym] = Chimera::RedisObjectProxy::ZSet.new(self, name, extra_opts)
          when :list then
            @redis_objects[name.to_sym] = Chimera::RedisObjectProxy::List.new(self, name, extra_opts)
          when :counter then
            @redis_objects[name.to_sym] = Chimera::RedisObjectProxy::Counter.new(self, name, extra_opts)
          end
        end
      end
    end # ClassMethods
    
    module InstanceMethods
      def destroy_redis_objects
        (@redis_objects || {}).each do |name, redis_obj|
          redis_obj.destroy
        end
      end
    end # InstanceMethods
  end
  
  module RedisObjectProxy
    class Base
      attr_accessor :owner, :name, :extra_opts
      def initialize(owner, name, extra_opts)
        unless owner and owner.id
          raise(Chimera::Errors::MissingId)
        end
        
        @owner = owner
        @name = name
        @extra_opts = extra_opts
      end
      
      def connection
        self.owner.class.connection(:redis)
      end
      
      def key
        "#{self.class.to_s}::RedisObjects::#{name}::#{self.owner.id}"
      end
      
      def destroy
        connection.del(self.key)
      end
    end
    
    class Collection < Base
      def sort(opts={})
        cmd = [self.key]
        cmd << "BY #{opts[:by_pattern]}" if opts[:by_pattern]
        if opts[:limit]
          start, count = opts[:limit]
          cmd << "LIMIT #{start} #{count}" if start && count
        end
        cmd << "GET #{opts[:get_pattern]}" if opts[:get_pattern]
        cmd << opts[:order] if opts[:order]
        cmd << "ALPHA" if opts[:alpha] == true
        cmd << "STORE #{opts[:dest_key]}" if opts[:dest_key]
        connection.sort(self.key, cmd.join(" "))
      end
    end
    
    class String < Base
      def set(val)
        connection.set(self.key, val)
      end
      
      def get
        connection.get(self.key)
      end
    end
    
    class Set < Collection
      def add(val)
        connection.sadd(self.key, val)
      end
      
      def <<(val)
        add(val)
      end
      
      def rem(val)
        connection.srem(self.key, val)
      end
      
      def pop
        connection.spop(self.key)
      end
      
      def move(val, dest_set_key)
        connection.smove(self.key, dest_set_key, val)
      end
      
      def card
        connection.scard(self.key)
      end
      
      alias :size :card
      alias :count :card
      
      def ismember(val)
        connection.sismember(self.key, val)
      end
      
      alias :is_member? :ismember
      alias :include? :ismember
      alias :includes? :ismember
      alias :contains? :ismember
      
      def inter(*set_keys)
        connection.sinter(set_keys.join(" "))
      end
      
      alias :intersect :inter
      
      def interstore(dest_key, *set_keys)
        connection.sinterstore(dest_key, set_keys.join(" "))
      end
      
      alias :intersect_and_store :interstore
      
      def union(*set_keys)
        connection.sunion(set_keys.join(" "))
      end
      
      def unionstore(dest_key, *set_keys)
        connection.sunionstore(dest_key, set_keys.join(" "))
      end
      
      alias :union_and_store :unionstore
      
      def diff(*set_keys)
        connection.sdiff(set_keys.join(" "))
      end
      
      def diffstore(dest_key, *set_keys)
        connection.sdiffstore(dest_key, set_keys.join(" "))
      end
      
      alias :diff_and_store :diffstore
      
      def members
        connection.smembers(self.key)
      end
      
      alias :all :members
      
      def randmember
        connection.srandmember(self.key)
      end
      
      alias :rand_member :randmember
    end
    
    class ZSet < Collection
      def add(val,score=0)
        connection.zadd(self.key, score, val)
      end
      
      def rem(val)
        connection.zrem(self.key, val)
      end
      
      def incrby(val, incr)
        connection.zincrby(self.key, incr, val)
      end
      
      alias :incr_by :incrby
      
      def range(start_index, end_index, extra_opts={})
        opts = [self.key, start_index, end_index]
        opts << "WITHSCORES" if extra_opts[:with_scores] == true
        connection.zrange(opts)
      end
      
      def revrange(start_index, end_index, extra_opts={})
        opts = [self.key, start_index, end_index]
        opts << "WITHSCORES" if extra_opts[:with_scores] == true
        connection.zrevrange(opts)
      end
      
      alias :rev_range :revrange
      
      def rangebyscore(min, max, extra_opts={})
        opts = [self.key, min, max]
        offset, count = extra_opts[:limit]
        if offset and count
          opts << "LIMIT #{offset} #{count}"
        end
        opts << "WITHSCORES" if extra_opts[:with_scores] == true
        connection.zrangebyscore(opts)
      end
      
      alias :range_by_score :rangebyscore
      
      def remrangebyscore(min,max)
        connection.zremrangebyscore(self.key,min,max)
      end
      
      alias :rem_range_by_score :remrangebyscore
      alias :remove_range_by_score :remrangebyscore
      
      def card
        connection.zcard(self.key)
      end
      
      alias :size :card
      alias :count :card
      
      def score(val)
        connection.zscore(self.key, val)
      end
    end
    
    class List < Collection
      def rpush(val)
        connection.rpush(self.key, val)
      end
      
      alias :right_push :rpush
      
      def <<(val)
        rpush(val)
      end
      
      def lpush(val)
        connection.lpush(self.key, val)
      end
      
      alias :left_push :lpush
      
      def len
        connection.len(self.key)
      end
      
      alias :size :len
      alias :count :len
      
      def range(start_index, end_index)
        connection.lrange(self.key, start_index, end_index)
      end
      
      def trim(start_index, end_index)
        connection.ltrim(self.key, start_index, end_index)
      end
      
      def index(index)
        connection.lindex(self.key, index)
      end
      
      def [](index)
        self.index(index)
      end
      
      def set(index, val)
        connection.lset(self.key, index, val)
      end
      
      def rem(val, count=0)
        connection.lrem(self.key, count, val)
      end
      
      def lpop
        connection.lpop(self.key)
      end
      
      alias :left_pop :lpop
      alias :pop :lpop
      
      def rpop
        connection.rpop(self.key)
      end
      
      alias :right_pop :rpop
      
      def rpoplpush(dest_key)
        connection.rpoplpush(self.key, dest_key)
      end
      
      alias :right_pop_left_push :rpoplpush
    end
    
    class Counter < Base      
      def incr
        connection.incr(self.key)
      end
      
      def incrby(val)
        connection.incrby(self.key,val)
      end
      
      alias :incr_by :incrby
      
      def decr
        connection.decr(self.key)
      end
      
      def decrby(val)
        connection.decrby(self.key, val)
      end
      
      def val
        connection.get(self.key).to_i
      end
      
      alias :count :val
      
      alias :decr_by :decrby
    end
  end
end