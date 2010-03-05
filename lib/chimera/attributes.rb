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
      def attribute(name, type = :string, extra_opts={})
        @defined_attributes ||= {}
        @defined_attributes[name.to_sym] = [type, extra_opts]
        define_method("#{name}") do
          return nil unless @attributes
          if type == :model
            @cached_attributes ||= {}
            @cached_attributes[name.to_sym] ||= begin
              model_id = @attributes[name.to_sym]
              klass = extra_opts[:class]
              if model_id && klass
                eval(klass.to_s.camelize).find(model_id)
              end
            end
          else
            @attributes[name.to_sym]
          end
        end
        define_method("#{name}=") do |val|
          return nil unless @attributes
          if type == :model
            @cached_attributes ||= {}
            @cached_attributes.delete(name.to_sym)
            if val.respond_to?(:id)
              @attributes[name.to_sym] = val.id
            else
              @attributes.delete(name.to_sym)
            end
          else @attributes
            @attributes[name.to_sym] = val
          end
        end
      end
    end # ClassMethods
    
    module InstanceMethods
    end # InstanceMethods
  end
end