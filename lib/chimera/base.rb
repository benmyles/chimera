module Chimera
  def self.config_path=(path)
    @config_path = path
    @config = YAML.load_file(@config_path)
  end
  
  def self.config
    @config || raise(Chimera::Error::MissingConfig)
  end
  
  class Base
    include Chimera::Attributes
    include Chimera::Indexes
    include Chimera::GeoIndexes
    include Chimera::Finders
    include Chimera::Persistence
    include ActiveModel::Validations

    extend ActiveModel::Naming
    extend ActiveModel::Callbacks
    define_model_callbacks :create, :save, :destroy
    
    attr_accessor :id, :attributes, :orig_attributes, :riak_response
    
    def self.use_config(key)
      @config = (Chimera.config[key.to_sym] || raise(Chimera::Error::MissingConfig,":#{key}"))
    end
    
    def self.config
      @config ||= (Chimera.config[:default] || raise(Chimera::Error::MissingConfig,":default"))
    end
    
    def self.connection(server)
      Thread.current["Chimera::#{self.to_s}::#{server}::connection"] ||= begin
        case server.to_sym
        when :redis
          Redis.new(self.config[:redis])
        when :riak_raw
          RiakRaw::Client.new(self.config[:riak_raw][:host], self.config[:riak_raw][:port])
        else
          nil
        end
      end
    end

    def self.bucket_key
      self.to_s
    end
    
    def self.bucket(keys=false)
      self.connection(:riak_raw).bucket(self.bucket_key,keys)
    end
    
    def self.new_uuid
      UUIDTools::UUID.random_create.to_s
    end
    
    def inspect
      "#<#{self.to_s}: @id=#{self.id}, @new=#{@new}>"
    end
    
    def ==(obj)
      obj.class.to_s == self.class.to_s &&
        !obj.new? && !self.new? &&
        obj.id == self.id
    end
    
    def <=>(obj)
      self.id.to_s <=> obj.id.to_s
    end
    
    def initialize(attributes={},id=nil,is_new=true)
      @attributes = attributes
      @orig_attributes = @attributes.clone
      @id = id
      @new = is_new
    end
    
    protected
    
    def read_attribute_for_validation(key)
      @attributes[key.to_sym]
    end
  end # Base
end # Chimera