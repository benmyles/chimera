module Chimera
  module Attributes
    def self.included(base)
      base.send :extend, ClassMethods
      base.send :include, InstanceMethods
    end
    
    module ClassMethods
      def defined_attributes
        @defined_attributes || {}
      end

      # available types include:
      #   string, integer, yaml, json, coordinate
      def attribute(name, type = :string)
        @defined_attributes ||= {}
        @defined_attributes[name.to_sym] = type
        define_method("#{name}") do
          if @attributes
            @attributes[name.to_sym]
          end
        end
        define_method("#{name}=") do |val|
          if @attributes
            @attributes[name.to_sym] = val
          end
        end
      end
    end # ClassMethods
    
    module InstanceMethods
    end # InstanceMethods
  end
end