# Intended for use with the thinking-sphinx gem. 
#
# The SphinxOptions class makes it easier to build up the options for a sphinx
# search over many lines of code. A SphinxOptions instance can NOT be passed
# directly to #search, you must pass the result of calling #to_hash on the
# SphinxOptions instance.
#
# Example:
#   so = SphinxOptions.new(name: 'Smith')
#   so.with!(age: 13)
#   User.search(so.to_hash)

class SphinxOptions < Hash
  attr_reader :distance, :point

  def initialize(options={})
    super() { |hash, key| hash[key] = {} }
    merge!(options)
  end

  def with_location!(location)
    with_point!(*GeoNames.location_to_point(location))
    self
  end

  def with_point!(latitude, longitude)
    @point = [latitude, longitude]
    self
  end

  def with_distance!(distance)
    @distance = distance
    self
  end

  def with_random!(random)
    self[:order] = 
      if random
        "@random ASC"
      else
        :start
      end

    self
  end

  def with!(options)
    self[:with].merge!(options)
    self
  end

  def condition!(options)
    self[:condition].merge!(options)
    self
  end

  def without!(options)
    self[:without].merge!(options)
    self
  end

  # You must pass the output of this function to sphinx instead of the
  # SphinxOptions object itself.
  def to_hash
    hash = {}.merge(self)

    if @distance && @point
      hash[:geo] = [@point[0].to_f * Math::PI / 180,
                    @point[1].to_f * Math::PI / 180]

      # Distance is in miles. We have to convert to meters before sending to
      # sphinx.
      distance_in_miles = Unit.new("#{@distance} miles").to("meters").scalar
      hash[:with]["@geodist"] = 0.0..distance_in_miles.to_f
    end

    hash
  end

  # Override #merge and #merge! to merge down one level so things like :with
  # merge correctly and copy over instance variables.
  def copy_instance_variables_from(other_options)
    if other_options.respond_to?(:distance) && other_options.distance
      @distance = other_options.distance
    end
    if other_options.respond_to?(:point) && other_options.point
      @point = other_options.point
    end
  end
  def merge_resolve(key, oldval, newval)
    if oldval.respond_to?(:merge) && newval.respond_to?(:merge)
      oldval.merge(newval)
    else
      newval
    end
  end
  def merge(other_options)
    merged = super { |k,o,n| merge_resolve(k,o,n) }
    merged.copy_instance_variables_from(other_options)
    merged
  end
  def merge!(other_options)
    copy_instance_variables_from(other_options)
    super { |k,o,n| merge_resolve(k,o,n) }
  end
end
