require File.dirname(__FILE__) + '/test_helper.rb'

class TestChimera < Test::Unit::TestCase
  def setup
    Car.each { |c| c.destroy }
    Car.connection(:redis).flush_all
    Car.allow_multi = true
  end
  
  def test_geo_indexes
    c = Car.new
    c.make = "Porsche"
    c.model = "911"
    c.year = 2010
    c.sku = 1000
    c.id = Car.new_uuid
    c.curr_location = [37.12122, 121.43392]
    assert c.save
    
    c2 = Car.new
    c2.make = "Toyota"
    c2.model = "Hilux"
    c2.year = 2010
    c2.sku = 1001
    c2.curr_location = [37.12222, 121.43792]
    c2.id = Car.new_uuid
    assert c2.save
    
    found = Car.find_with_index(:curr_location, {:coordinate => [37.12222, 121.43792], :steps => 5})
    assert_equal [c,c2].sort, found.sort
    
    c2.curr_location = [38.0, 122.0]
    assert c2.save
    
    found = Car.find_with_index(:curr_location, {:coordinate => [37.12222, 121.43792], :steps => 5})
    assert_equal [c].sort, found.sort
    
    found = Car.find_with_index(:curr_location, {:coordinate => [38.0-0.05, 122.0+0.05], :steps => 5})
    assert_equal [c2].sort, found.sort
  end
  
  def test_search_indexes
    c = Car.new
    c.make = "Porsche"
    c.model = "911"
    c.year = 2010
    c.sku = 1000
    c.comments = "cat dog chicken dolphin whale panther"
    c.id = Car.new_uuid
    assert c.save
    
    c2 = Car.new
    c2.make = "Porsche"
    c2.model = "911"
    c2.year = 2010
    c2.sku = 1001
    c2.comments = "cat dog chicken"
    c2.id = Car.new_uuid
    assert c2.save
  
    c3 = Car.new
    c3.make = "Porsche"
    c3.model = "911"
    c3.year = 2010
    c3.sku = 1002
    c3.comments = "dog chicken dolphin whale"
    c3.id = Car.new_uuid
    assert c3.save
    
    assert_equal [c,c2,c3].sort, Car.find_with_index(:comments, "dog").sort
    assert_equal [c,c2].sort, Car.find_with_index(:comments, "cat").sort
    assert_equal [c,c2].sort, Car.find_with_index(:comments, "cat").sort
  
    assert_equal [c,c2,c3].sort, Car.find_with_index(:comments, {:q => "dog dolphin", :type => :union}).sort
    assert_equal [c,c3].sort, Car.find_with_index(:comments, {:q => "dog dolphin", :type => :intersect}).sort
  end
  
  def test_indexes
    c = Car.new
    c.make = "Nissan"
    c.model = "RX7"
    c.year = 2010
    c.sku = 1001
    c.comments = "really fast car. it's purple too!"
    c.id = Car.new_uuid
    assert c.save
    
    assert !c.new?
    
    assert_equal [c], Car.find_with_index(:comments, "fast")
    assert_equal [c], Car.find_with_index(:comments, "purple")
    assert_equal [], Car.find_with_index(:comments, "blue")
    
    assert_equal [c], Car.find_with_index(:year, 2010)
    assert_equal [c], Car.find_with_index(:sku, 1001)
    
    c2 = Car.new
    c2.make = "Honda"
    c2.model = "Accord"
    c2.year = 2010
    c2.sku = 1001
    c2.id = Car.new_uuid
    assert_raise(Chimera::Error::UniqueConstraintViolation) { c2.save }
    c2.sku = 1002
    assert c2.save
    
    c3 = Car.new
    c3.make = "Honda"
    c3.model = "Civic"
    c3.year = 2010
    c3.sku = 1003
    c3.id = Car.new_uuid
    assert c3.save
    
    assert_equal 3, Car.find_with_index(:year, 2010).size
    assert Car.find_with_index(:year, 2010).include?(c)
    assert Car.find_with_index(:year, 2010).include?(c2)
    assert Car.find_with_index(:year, 2010).include?(c3)
    
    count = 0
    Car.find_with_index(:all) { |car| count += 1 }
    assert_equal 3, count
    
    count = 0
    Car.each { |car| count += 1 }
    assert_equal 3, count
    
    c2.destroy
    
    count = 0
    Car.find_with_index(:all) { |car| count += 1 }
    assert_equal 2, count
    
    count = 0
    Car.each { |car| count += 1 }
    assert_equal 2, count
  end
  
  def test_associations
    u = User.new
    u.id = User.new_uuid
    u.name = "Ben"
    assert u.save
    
    assert_equal 0, u.friends.size
    
    chris = User.new
    chris.id = User.new_uuid
    chris.name = "Chris"
    assert chris.save
    
    assert_equal 0, u.friends.size
    u.friends << chris
    assert_equal 1, u.friends.size
    chris.destroy
    assert_equal 0, u.friends.size
    
    c = Car.new
    c.make = "Nissan"
    c.model = "RX7"
    c.year = 2010
    c.sku = 1001
    c.comments = "really fast car. it's purple too!"
    c.id = Car.new_uuid
    assert c.save
    
    assert_equal 0, u.cars.size
    u.cars << c
    assert_equal 1, u.cars.size
    assert_equal [c], u.cars.all
    assert_equal 1, c.association_memberships.all_associations.size
    u.cars.remove(c)
    assert_equal 0, c.association_memberships.all_associations.size
  end
  
  def test_model_attribute
    u = User.new
    u.id = User.new_uuid
    u.name = "Ben"
    assert u.save
    assert_nil u.favorite_car
    
    c = Car.new
    c.make = "Nissan"
    c.model = "RX7"
    c.year = 2010
    c.sku = 1001
    c.comments = "really fast car. it's purple too!"
    c.id = Car.new_uuid
    assert c.save
    
    u.favorite_car = c
    assert u.save
    assert_equal c, u.favorite_car
    u = User.find(u.id)
    assert_equal c, u.favorite_car
    u.favorite_car = nil
    assert u.save
    assert_nil u.favorite_car
    
    u.favorite_car = c
    assert u.save
    assert_equal c, u.favorite_car
    c.destroy
    assert_equal c, u.favorite_car
    u = User.find(u.id)
    assert_nil u.favorite_car
  end
  
  def test_redis_objects
    u = User.new
    u.id = User.new_uuid
    u.name = "Ben"
    assert u.save
    
    assert_equal false, User.connection(:redis).exists(u.num_logins.key)
    assert_equal 0, u.num_logins.count
    u.num_logins.incr
    assert_equal 1, u.num_logins.count
    assert_equal true, User.connection(:redis).exists(u.num_logins.key)
    u.num_logins.incr_by 10
    assert_equal 11, u.num_logins.count
    
    u.destroy
    
    assert_equal false, User.connection(:redis).exists(u.num_logins.key)
  end
  
  def test_rich_attributes
    u = User.new
    u.id = User.new_uuid
    u.updated_at = Time.now.utc
    assert u.updated_at.is_a?(Time)
    u.name = "ben"
    assert u.save
    u = User.find(u.id)
    assert u.updated_at.is_a?(Time)
  end
  
  def test_conflicts
    Car.connection(:riak_raw).client_id = "Client1"
    c = Car.new
    c.id = Car.new_uuid
    c.make = "Nissan"
    c.model = "Versa"
    c.year = 2009
    assert c.save
    
    c2 = c.clone
    Car.connection(:riak_raw).client_id = "Client2"
    c2.year = 2008
    assert c2.save
    
    assert !c2.in_conflict?
    
    Car.connection(:riak_raw).client_id = "Client3"
    c.year = 2007
    assert c.save
    
    assert c.in_conflict?
    assert_raise(Chimera::Error::CannotSaveWithConflicts) { c.save }
    
    c2 = Car.find(c.id)
    #puts c2.attributes.inspect
    #puts c2.sibling_attributes.inspect
    
    c.attributes = c.sibling_attributes.first[1].dup
    c.year = 2006
    assert c.resolve_and_save
    
    assert !c.in_conflict?
    
    c = Car.find(c.id)
    assert !c.in_conflict?
    assert_equal 2006, c.year
  end
  
  # test based on http://blog.basho.com/2010/01/29/why-vector-clocks-are-easy/
  def test_riak_siblings
    Chimera::Base.connection(:riak_raw).delete("plans","dinner")
    props = Chimera::Base.connection(:riak_raw).bucket("plans")
    props["props"]["allow_mult"] = true
    Chimera::Base.connection(:riak_raw).set_bucket_properties("plans",props)
    props = Chimera::Base.connection(:riak_raw).bucket("plans")
    
    alice_client = Chimera::Base.new_connection(:riak_raw)
    alice_client.client_id = "Alice"
  
    ben_client = Chimera::Base.new_connection(:riak_raw)
    ben_client.client_id = "Ben"
  
    kathy_client = Chimera::Base.new_connection(:riak_raw)
    kathy_client.client_id = "Kathy"
  
    dave_client = Chimera::Base.new_connection(:riak_raw)
    dave_client.client_id = "Dave"
    
    alice_resp = alice_client.store("plans","dinner","Wednesday")
    
    # When Ben, Kathy, and Dave each GET Alice's plans, they'll get the same vector clock 
    ben_resp = ben_client.fetch("plans","dinner")
    kathy_resp = kathy_client.fetch("plans","dinner")
    dave_resp = dave_client.fetch("plans","dinner")
    
    # Now when Ben sends his change to Dave, he includes both the vector clock he pulled down 
    # (in the X-Riak-Vclock header), and his own X-Riak-Client-Id:
    ben_resp = ben_client.store("plans","dinner","Tuesday",ben_resp.headers_hash['X-Riak-Vclock'])
    # Dave pulls down a fresh copy, and then confirms Tuesday:
    dave_resp = dave_client.fetch("plans","dinner")
    dave_resp = dave_client.store("plans","dinner","Tuesday",dave_resp.headers_hash['X-Riak-Vclock'])
    # Kathy, on the other hand, hasn't pulled down a new version, and instead merely updated 
    # the plans with her suggestion of Thursday:
    kathy_client.store("plans","dinner","Thursday",kathy_resp.headers_hash['X-Riak-Vclock'])
    
    # Now, when Dave goes to grab this new copy (after Cathy tells him she has posted it), he'll 
    # see one of two things. If the "plans" Riak bucket has the allow_mult property set to false, 
    # he'll see just Cathy's update. If allow_mult is true for the "plans" bucket, he'll see both 
    # his last update and Cathy's. I'm going to show the allow_mult=true version below, because I 
    # think it illustrates the flow better.
    dave_resp = dave_client.fetch("plans","dinner")
    
    assert dave_resp.body =~ /^Siblings/
    siblings = dave_resp.body.split("\n")[1..-1]
    # puts siblings.inspect
    # puts dave_resp.code
    
    sib1 = dave_client.fetch("plans","dinner",:vtag => siblings[0])
    # puts sib1.body
  end
end
