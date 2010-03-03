module Chimera
  module GeoIndexes
    def self.included(base)
      base.send :extend, ClassMethods
      base.send :include, InstanceMethods
    end
    
    module ClassMethods
      def key_for_geo_index(type, name, lat, lon, step_size=0.05)
        step_size ||= 0.05
        case type.to_sym
        when :geo then
          lat = geo_square_coord(lat)
          lon = geo_square_coord(lon)
          "#{self.to_s}::Indexes::#{type}::#{name}::#{step_size}::#{lat}::#{lon}"
        end
      end
      
      def find_with_geo_index(name, opts_or_query)
        if props = self.defined_indexes[name.to_sym]
          case props[:type]
          when :geo then
            step_size = props[:step_size]
            num_steps = opts_or_query[:steps] || 5
            steps = [50,num_steps].min * step_size
            lat, lon = opts_or_query[:coordinate]
            union_keys = []
            curr_lat = lat - steps
            while curr_lat < lat+steps
              curr_lon = lon - steps
              while curr_lon < lon+steps
                union_keys << key_for_geo_index(:geo,name,curr_lat,curr_lon,step_size)
                curr_lon += step_size
              end
              curr_lat += step_size
            end
            keys = self.connection(:redis).sunion(union_keys.join(" "))
            find_many(keys)
          end # case
        end # if props =
      end
      
      def geo_square_coord(lat_or_lon, step=0.05)
        i = (lat_or_lon*1000000).floor
        i += (step/2)*1000000
        (i - (i % (step * 1000000)))/1000000
      end
    end
    
    module InstanceMethods
      def destroy_geo_indexes
        self.class.defined_indexes.each do |name, props|
          case props[:type]
          when :geo then
            if val = @orig_attributes[name.to_sym] and val.is_a?(Array)
              index_key = self.class.key_for_geo_index(:geo, name, val[0], val[1], props[:step_size])
              self.class.connection(:redis).srem(index_key, self.id)
            end
          end # case props[:type]
        end # self.class.defined_indexes
      end # destroy_geo_indexes
      
      def create_geo_indexes
        self.class.defined_indexes.each do |name, props|
          case props[:type]
          when :geo then
            if val = @attributes[name.to_sym] and val.is_a?(Array)
              index_key = self.class.key_for_geo_index(:geo, name, val[0], val[1], props[:step_size])
              self.class.connection(:redis).sadd(index_key, self.id)
            end
          end # case props[:type]
        end # self.class.defined_indexes
      end # create_geo_indexes
    end
  end
end