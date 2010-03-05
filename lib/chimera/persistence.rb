module Chimera
  module Persistence
    def self.included(base)
      base.send :extend, ClassMethods
      base.send :include, InstanceMethods
    end
    
    module ClassMethods
    end # ClassMethods
    
    module InstanceMethods
      def new?
        @new == true
      end

      def save
        raise(Chimera::Error::SaveWithoutId) unless self.id
        raise(Chimera::Error::ValidationErrors) unless self.valid?
        check_index_constraints
        
        if new?
          _run_create_callbacks do
            _run_save_callbacks do
              save_without_callbacks
              create_indexes
            end
          end
        else
          _run_save_callbacks do
            destroy_indexes
            save_without_callbacks
            create_indexes
          end
        end
        
        true
      end
      
      alias :create :save
      
      def vector_clock
        if @riak_response and @riak_response.headers_hash
          return @riak_response.headers_hash["X-Riak-Vclock"]
        end; nil
      end
      
      def save_without_callbacks
        @riak_response = self.class.connection(:riak_raw).store(
          self.class.bucket_key,
          self.id, 
          Yajl::Encoder.encode(@attributes),
          self.vector_clock)

        @orig_attributes = @attributes.clone
        @new = false
      end

      def destroy
        _run_destroy_callbacks do
          @riak_response = self.class.connection(:riak_raw).delete(self.class.bucket_key, self.id)
          destroy_indexes
          association_memberships.destroy
          destroy_associations
          destroy_redis_objects
          freeze
        end
      end
    end # InstanceMethods
  end
end