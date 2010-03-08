module Chimera
  module Persistence
    def self.included(base)
      base.send :extend, ClassMethods
      base.send :include, InstanceMethods
    end
    
    module ClassMethods
      # allows for multiple conflicting values from riak
      def allow_multi=(val)
        props = self.bucket
        props["props"]["allow_mult"] = val
        self.connection(:riak_raw).set_bucket_properties(self.to_s,props)
      end
    end # ClassMethods
    
    module InstanceMethods
      def new?
        @new == true
      end
      
      def in_conflict?
        !self.sibling_attributes.nil?
      end
      
      def load_sibling_attributes
        return nil unless self.riak_response.body =~ /^Sibling/
        vtags = self.riak_response.body.split("\n")[1..-1]
        if vtags.empty?
          self.sibling_attributes = nil
        else
          self.sibling_attributes = {}
          vtags.each do |vtag|
            if resp = self.class.connection(:riak_raw).fetch(self.class.to_s, self.id, {"vtag" => vtag})
              self.sibling_attributes[vtag] = YAML.load(resp.body)
            else
              self.sibling_attributes[vtag] = {}
            end
          end
        end
      end # load_sibling_attributes
      
      def resolve_and_save
        if valid?
          self.sibling_attributes = nil
          save
        end
      end

      def save
        verify_can_save!
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
        verify_can_save!
        
        @riak_response = self.class.connection(:riak_raw).store(
          self.class.bucket_key,
          self.id, 
          YAML.dump(@attributes),
          self.vector_clock)
        
        case @riak_response.code
        when 300 then
          self.load_sibling_attributes
        when 200 then
          # all good
        else
          raise(Chimera::Error::UnhandledRiakResponseCode.new(@riak_response.code))
        end
        
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
      
      protected
      
      def verify_can_save!
        raise(Chimera::Error::SaveWithoutId) unless self.id
        raise(Chimera::Error::ValidationErrors) unless self.valid?
        raise(Chimera::Error::CannotSaveWithConflicts) if self.in_conflict?
      end
    end # InstanceMethods
  end
end