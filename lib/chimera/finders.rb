module Chimera
  module Finders
    MAX_FINDER_THREADS = 20
    
    def self.included(base)
      base.send :extend, ClassMethods
      base.send :include, InstanceMethods
    end
    
    module ClassMethods
      def each
        self.find_with_index(:all) { |obj| yield(obj) }
      end
      
      def find(key,opts={})
        find_many([[key,opts]])[0]
      end
      
      def find_many(key_opts_arr)
        found   = []
        key_opts_arr = Array(key_opts_arr).collect { |e| Array(e) }
        key_opts_arr.in_groups_of(Chimera::Finders::MAX_FINDER_THREADS).each do |key_opts_arr_group|
          threads = []
          key_opts_arr_group.compact.each do |key,opts|
            opts ||= {}
            threads << Thread.new do
              if key
                resp = self.connection(:riak_raw).fetch(self.to_s, key, opts)
                case resp.code
                when 300 then
                  # siblings
                  obj = self.new({},key,false)
                  obj.riak_response = resp
                  obj.load_sibling_attributes
                  found << obj
                when 200 then
                  if resp.body and yaml_hash = YAML.load(resp.body)
                    hash = {}
                    yaml_hash.each { |k,v| hash[k.to_sym] = v }
                    obj = self.new(hash,key,false)
                    obj.riak_response = resp
                    found << obj
                  else
                    obj = self.new({},key,false)
                    obj.riak_response = resp
                    found << obj
                  end
                when 404 then
                  nil
                else
                  raise(Chimera::Error::UnhandledRiakResponseCode.new(resp.code.to_s))
                end # case
              end
            end # Thread.new
          end # key_opts_arr_group.each
          threads.each { |th| th.join }
        end # key_opts_arr.in_groups_of(10).each do |key_opts_arr_group|
        found
      end # find_many
    end # ClassMethods
    
    module InstanceMethods
    end # InstanceMethods
  end
end