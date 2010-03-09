module Chimera
  module Indexes
    SEARCH_EXCLUDE_LIST = %w(a an and as at but by for in into of on onto to the)
    
    def self.included(base)
      base.send :extend, ClassMethods
      base.send :include, InstanceMethods
    end
    
    module ClassMethods
      def defined_indexes
        @defined_indexes || {}
      end

      # available types include:
      #   find, unique, search, geo
      def index(name, type = :find)
        @defined_indexes ||= {}
        @defined_indexes[name.to_sym] = type
      end
      
      def find_with_index(name, opts_or_query=nil)
        if opts_or_query.is_a?(Hash)
          q = opts_or_query[:q].to_s
          offset = opts_or_query[:offset] || opts_or_query[:lindex] || 0
          limit = opts_or_query[:limit] || opts_or_query[:rindex] || -1
        else
          q = opts_or_query.to_s
          offset = 0
          limit = -1
        end
        
        if name.to_sym == :all
          llen  = self.connection(:redis).llen(self.key_for_all_index)
          limit = llen if limit > llen || limit == -1
          curr  = offset
          while(curr < limit)
            max_index = [curr+9,limit-1].min
            keys = self.connection(:redis).lrange(self.key_for_all_index, curr, max_index).compact
            self.find_many(keys).each { |obj| yield(obj) }
            curr += 10
          end
        elsif props = self.defined_indexes[name.to_sym]
          case props[:type]
          when :find then
            if q and !q.blank?
              index_key = self.key_for_index(:find, name, q)
              self.find_many(self.connection(:redis).zrange(index_key, offset, limit))
            end
          when :unique then
            if q and !q.blank?
              index_key = self.key_for_index(:unique, name, q)
              Array(self.find(self.connection(:redis).get(index_key)))
            end
          when :search then
            if opts_or_query.is_a?(Hash)
              opts_or_query[:type] ||= :intersect
            end
            
            keys = []
            q.split(" ").each do |word|
              word = word.downcase.stem
              next if Chimera::Indexes::SEARCH_EXCLUDE_LIST.include?(word)
              keys << self.key_for_index(:search, name, word)
            end
            if keys.size > 0
              result_set_key = UUIDTools::UUID.random_create.to_s
              if opts_or_query.is_a?(Hash) and opts_or_query[:type] == :union
                #self.find_many(self.connection(:redis).sunion(keys.join(" ")))
                self.connection(:redis).zunion(result_set_key, keys.size, keys.join(" "))
              else
                #self.find_many(self.connection(:redis).sinter(keys.join(" ")))
                self.connection(:redis).zinter(result_set_key, keys.size, keys.join(" "))
              end
              results = self.find_many(self.connection(:redis).zrange(result_set_key, offset, limit))
              self.connection(:redis).del(result_set_key)
              results
            end # if keys.size
          when :geo then
            find_with_geo_index(name, opts_or_query)
          end # case
        end # if props
      end
      
      def key_for_index(type, name, val)
        case type.to_sym
        when :find, :unique, :search then
          "#{self.to_s}::Indexes::#{type}::#{name}::#{digest(val)}"
        end
      end
      
      def key_for_all_index
        "#{self.to_s}::Indexes::All"
      end
      
      def digest(val)
        Digest::SHA1.hexdigest(val)
      end
    end # ClassMethods
    
    module InstanceMethods
      def destroy_indexes
        remove_from_all_index
        self.class.defined_indexes.each do |name, props|
          case props[:type]
          when :find then
            if val = @orig_attributes[name.to_sym] and !val.blank?
              index_key = self.class.key_for_index(:find, name,val.to_s)
              self.class.connection(:redis).zrem(index_key, self.id)
            end
          when :unique then
            if val = @orig_attributes[name.to_sym] and !val.blank?
              index_key = self.class.key_for_index(:unique, name,val.to_s)
              self.class.connection(:redis).del(index_key)
            end
          when :search then
            if val = @orig_attributes[name.to_sym] and !val.blank?
              val.to_s.split(" ").each do |word|
                word = word.downcase.stem
                next if Chimera::Indexes::SEARCH_EXCLUDE_LIST.include?(word)
                index_key = self.class.key_for_index(:search, name, word)
                #self.class.connection(:redis).srem(index_key, self.id)
                self.class.connection(:redis).zrem(index_key, self.id)
              end
            end
          end
        end
        destroy_geo_indexes
      end
      
      def check_index_constraints
        self.class.defined_indexes.each do |name, props|
          case props[:type]
          when :unique then
            if val = @attributes[name.to_sym] and !val.blank?
              index_key = self.class.key_for_index(:unique, name,val.to_s)
              if k = self.class.connection(:redis).get(index_key)
                if k.to_s != self.id.to_s
                  raise(Chimera::Error::UniqueConstraintViolation, val)
                end
              end
            end # if val
          end # case
        end
      end
      
      def create_indexes
        add_to_all_index
        self.class.defined_indexes.each do |name, props|
          case props[:type]
          when :find then
            if val = @attributes[name.to_sym] and !val.blank?
              index_key = self.class.key_for_index(:find, name, val.to_s)
              self.class.connection(:redis).zadd(index_key, Time.now.utc.to_f, self.id)
            end
          when :unique then
            if val = @attributes[name.to_sym] and !val.blank?
              index_key = self.class.key_for_index(:unique, name,val.to_s)
              if self.class.connection(:redis).exists(index_key)
                raise(Chimera::Error::UniqueConstraintViolation, val)
              else
                self.class.connection(:redis).set(index_key, self.id)
              end
            end
          when :search then
            if val = @attributes[name.to_sym] and !val.blank?
              val.to_s.split(" ").each do |word|
                word = word.downcase.stem
                next if Chimera::Indexes::SEARCH_EXCLUDE_LIST.include?(word)
                index_key = self.class.key_for_index(:search, name, word)
                #self.class.connection(:redis).sadd(index_key, self.id)
                self.class.connection(:redis).zadd(index_key, Time.now.utc.to_f, self.id)
              end
            end
          end
        end
        create_geo_indexes
      end
      
      def update_indexes
        destroy_indexes
        destroy_geo_indexes
        create_indexes
        create_geo_indexes
      end
      
      def remove_from_all_index
        self.class.connection(:redis).lrem(self.class.key_for_all_index, 0, self.id)
      end
      
      def add_to_all_index
        self.class.connection(:redis).lpush(self.class.key_for_all_index, self.id)
      end
    end # InstanceMethods
  end
end