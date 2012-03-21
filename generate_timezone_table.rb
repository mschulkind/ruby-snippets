#!/usr/bin/env ruby

require 'bundler'
Bundler.require
require_relative 'geo_names.rb'

script_dir = File.dirname(__FILE__)

regions = {}
RGeo::Shapefile::Reader.open(
  File.join(script_dir, 'timezone_data/tz_us')) do |reader|
  reader.each do |record|
    regions[record.geometry] = record.attributes
  end
end

zip_code_count = GeoNames.zip_codes.count

zip_code_tz_map = {}
GeoNames.zip_codes.each do |zc|
  lat, long = GeoNames.location_to_point(zc)
  point = RGeo::Cartesian.factory.point(long, lat)

  containing_shapes = regions.keys.find_all { |s| s.contains?(point) }
  if containing_shapes.count == 1
    shape = containing_shapes.first
  else
    # If the point didn't fall in exactly one region, find the closest region.
    shape = regions.keys.sort_by { |s| s.distance(point) }.first
  end

  zip_code_tz_map[zc] = regions[shape]['TZID']

  if zip_code_tz_map.keys.count % 100 == 0
    puts "Looked up #{zip_code_tz_map.keys.count}/#{zip_code_count} zip codes..."
  end
end

File.open("zip_code_to_tz.yml", "w") { |f| f << zip_code_tz_map.to_yaml }

puts "Done"
