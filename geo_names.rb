module GeoNames
  def self.array_average(array)
    array.inject(:+) / array.count
  end

  def self.soundex_for_location(location)
    Text::Soundex.soundex(location.downcase.tr('^a-z', ''))
  end

  def self.location_for_trie(location)
    location.downcase.tr('^a-z', '')
  end

  def self.load_cities_maps
    # Maps 'City, XX' -> [lat, long].
    @cities_lat_long_map = {}

    # Maps soundex to 'City, XX'.
    @cities_soundex_map = {}

    # Maps '12345' -> 'City, XX'.
    @cities_zip_code_map = {}

    # Maps 'City, State Name' -> 'City, XX'.
    @cities_long_state_name_map = {}

    @cities_trie = Trie.new
    File.read('geonames_data/US.txt').lines.each do |line|
      fields = line.split("\t")
      zip = fields[1]
      city = fields[2]
      state = fields[3]
      state_abbreviation = fields[4]
      latitude = fields[9].to_f
      longitude = fields[10].to_f

      # Add to the lat/long map.
      location = "#{city}, #{state_abbreviation}"
      @cities_lat_long_map[location] ||= []
      @cities_lat_long_map[location] << [latitude, longitude]

      # Add to the soundex map.
      soundex_key = soundex_for_location(location)
      @cities_soundex_map[soundex_key] ||= Set.new
      @cities_soundex_map[soundex_key] << location

      # Add to the zipcode map.
      @cities_zip_code_map[zip] = location

      # Add to the long state name map.
      @cities_long_state_name_map["#{city}, #{state}"] = location
 
      # Add to the trie.
      @cities_trie.insert(location_for_trie(location), location)
    end

    # Reduce all lat_long hashes to a single averaged value.
    @cities_lat_long_map.each do |k, v|
      latitude = array_average(v.map { |ll| ll[0] })
      longitude = array_average(v.map { |ll| ll[1] })
      @cities_lat_long_map[k] = [latitude, longitude]
    end
  end
  load_cities_maps

  @city_rewrites = {
    'New York, NY' => 'New York City, NY'
  }

  class LocationNotFound < StandardError; end
  def self.location_to_point(location)
    location = 
      @city_rewrites[location] || 
      @cities_zip_code_map[location] || 
      @cities_long_state_name_map[location] ||
      location
    point = @cities_lat_long_map[location]

    raise LocationNotFound, "'#{location}' not found" unless point

    point
  end

  def self.locations_sounding_like(location)
    @cities_soundex_map[soundex_for_location(location)].to_a
  end

  def self.locations_starting_with(prefix)
    transformed_prefix = location_for_trie(prefix) 
    if transformed_prefix.empty? && !prefix.empty?
      # If the transformation turned the prefix into an empty string, don't
      # return any results so stuff like '12345' won't return everything.
      []
    else
      @cities_trie.find_prefix(transformed_prefix).values
    end
  end

  def self.location_for_zip_code(zip_code)
    @cities_zip_code_map[zip_code]
  end

  def self.zip_codes
    @cities_zip_code_map.keys
  end

  def self.load_timezone_map
    @timezone_map = 
      YAML::load(File.read('zip_code_to_tz.yml'))
  end
  load_timezone_map

  def self.timezone_for_zip_code(zip_code)
    TZInfo::Timezone.get(@timezone_map[zip_code])
  end
end
