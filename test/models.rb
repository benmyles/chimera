class User < Chimera::Base
  use_config :default # this is implied even if not here
  
  attribute :name, :string
  attribute :age, :integer
  attribute :occupation, :string
  attribute :interests, :json
  attribute :home_coordinate, :coordinate # [37.2,122.1]
  attribute :ssn, :string
  attribute :favorite_car, :model, :class => :car
  
  # User.find_with_index(:home_coordinate, {:coordinate => [37.2,122.1], :steps => 5})
  index :home_coordinate, :type => :geo, :step_size => 0.05
  
  # User.find_with_index(:occupation, { :q => "developer", :type => :intersect } ) # fuzzy search. :intersect or :union
  index :occupation, :type => :search
  
  # User.find_with_index(:ssn, "12345") # exact search, enforces unique constraint
  index :ssn, :type => :unique
  
  # User.find_with_index(:name, "Ben") # like :search but exact
  index :name, :type => :find
  
  association :friends, :user
  association :cars, :car
  
  redis_object :num_logins, :counter
  
  validates_presence_of :name
end

class Car < Chimera::Base
  attribute :color
  attribute :make
  attribute :model
  attribute :year, :integer
  attribute :mileage, :integer
  attribute :comments
  attribute :sku
  attribute :curr_location, :coordinate
  
  index :year, :type => :find
  index :comments, :type => :search
  index :sku, :type => :unique
  index :curr_location, :type => :geo, :step_size => 0.05
  
  validates_presence_of :make, :model, :year
end