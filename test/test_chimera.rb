require File.dirname(__FILE__) + '/test_helper.rb'

class TestChimera < Test::Unit::TestCase
  def setup
    Car.each { |c| c.destroy }
    Car.connection(:redis).flush_all
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
end
