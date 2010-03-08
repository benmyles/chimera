module Chimera
  module Associations
    def self.included(base)
      base.send :extend, ClassMethods
      base.send :include, InstanceMethods
    end
    
    module ClassMethods
      def defined_associations
        @defined_associations || {}
      end

      # association :friends, User
      def association(name, class_sym)
        @defined_associations ||= {}
        @defined_associations[name.to_sym] = class_sym
        define_method("#{name}") do
          @associations ||= {}
          @associations[name] ||= Chimera::AssociationProxies::Association.new(self,name,class_sym)
        end
      end
    end # ClassMethods
    
    module InstanceMethods
      def destroy_associations
        (@associations || {}).each do |name, association|
          association.destroy
        end
      end
      
      def association_memberships
        @association_memberships ||= Chimera::AssociationProxies::AssociationMemberships.new(self)
      end
    end # InstanceMethods
  end
  
  module AssociationProxies
    class AssociationMemberships
      attr_accessor :model
      
      def initialize(_model)
        @model = _model
      end
      
      def key
        "#{model.class.to_s}::AssociationProxies::AssociationMemberships::#{model.id}"
      end
      
      def add(assoc_key)
        self.model.class.connection(:redis).lpush(self.key, assoc_key)
      end
      
      def remove(assoc_key)
        self.model.class.connection(:redis).lrem(self.key, 0, assoc_key)
      end
      
      def destroy
        remove_from_all_associations
        self.model.class.connection(:redis).del(self.key)
      end
      
      def remove_from_all_associations
        self.each_association { |assoc| assoc.remove(self.model) }
      end
      
      def each_association
        llen  = self.model.class.connection(:redis).llen(self.key)
        0.upto(llen-1) do |i|
          assoc_key = self.model.class.connection(:redis).lindex(self.key, i)
          yield Chimera::AssociationProxies::Association.find(assoc_key)
        end
        true
      end
      
      def all_associations
        all = []; self.each_association { |ass| all << ass }; all
      end
    end
    
    class Association
      attr_accessor :model, :name, :klass
      
      def self.find(assoc_key)
        parts = assoc_key.split("::")
        model_klass = parts[0]
        name = parts[3]
        assoc_klass = parts[4]
        model_id = parts[5]
        self.new(eval(model_klass).find(model_id), name, assoc_klass.to_sym)
      end
      
      def initialize(_model, _name, class_sym)
        @model = _model
        @name  = _name
        @klass = eval(class_sym.to_s.camelize)
        raise(Chimera::Error::MissingId) unless model.id
      end

      def key
        "#{model.class.to_s}::AssociationProxies::Association::#{name}::#{klass.to_s}::#{model.id}"
      end

      def <<(obj)
        raise(Chimera::Error::AssociationClassMismatch) unless obj.class.to_s == self.klass.to_s
        self.model.class.connection(:redis).lpush(self.key, obj.id)
        obj.association_memberships.add(self.key)
        true
      end

      def remove(obj)
        raise(Chimera::Error::AssociationClassMismatch) unless obj.class.to_s == self.klass.to_s
        self.model.class.connection(:redis).lrem(self.key, 0, obj.id)
        obj.association_memberships.remove(self.key)
        true
      end

      def size
        self.model.class.connection(:redis).llen(self.key)
      end

      def each(limit=nil)
        llen  = self.model.class.connection(:redis).llen(self.key)
        limit ||= llen
        curr  = 0
        while(curr < limit)
          max_index = [curr+9,limit-1].min
          keys = self.model.class.connection(:redis).lrange(self.key, curr, max_index).compact
          self.klass.find_many(keys).each { |obj| yield(obj) }
          curr += 10
        end
        true
      end
      
      def all
        found = []; self.each { |o| found << o }; found
      end

      def destroy(delete_associated=true)
        if delete_associated == true
          self.each { |obj| obj.destroy }
        else
          self.each { |obj| obj.association_memberships.remove(self.key) }
        end
        self.model.class.connection(:redis).del(self.key)
      end
    end # Association
  end # AssociationProxies
end