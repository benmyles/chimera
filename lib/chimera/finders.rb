module Chimera
  module Finders
    def self.included(base)
      base.send :extend, ClassMethods
      base.send :include, InstanceMethods
    end
    
    module ClassMethods
      def each
        self.find_with_index(:all) { |obj| yield(obj) }
      end
      
      def find(key)
        find_many(key)[0]
      end
      
      def find_many(keys)
        keys    = Array(keys)
        found   = []
        threads = []
        keys.each do |key|
          threads << Thread.new do
            if key
              resp = self.connection(:riak_raw).fetch(self.to_s, key)
              if resp.code == 200
                if resp.body and json_hash = Yajl::Parser.parse(resp.body)
                  hash = {}
                  json_hash.each { |k,v| hash[k.to_sym] = v }
                  obj = self.new(hash,key,false)
                  obj.riak_response = resp
                  found << obj
                else
                  obj = self.new({},key,false)
                  obj.riak_response = resp
                  found << obj
                end
              end
            end
          end # Thread.new
        end # keys.each
        threads.each { |th| th.join }
        found
      end # find_many
    end # ClassMethods
    
    module InstanceMethods
    end # InstanceMethods
  end
end