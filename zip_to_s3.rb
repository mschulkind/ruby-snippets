# Uses the following gems:
#   rubyzip
#   bzip2-ruby
#   aws-s3

def establish_s3_connection!
  AWS::S3::Base.establish_connection!(
    access_key_id: ENV['AMAZON_ACCESS_KEY_ID'], 
    secret_access_key: ENV['AMAZON_SECRET_ACCESS_KEY']
  )
end

establish_s3_connection!

local_file_name = 'bar/foo.zip'
bucket = 'my-upload-bucket'
s3_prefix = 'upload/'

zip = Zip::ZipInputStream.open(local_file_name)
prefix = "#{s3_prefix}"
while (entry = zip.get_next_entry)
  puts "Reading '#{entry.name}' from zip..."
  data = entry.get_input_stream.read

  puts "Compressing..."
  compressor = Bzip2::Writer.new
  compressor << data
  compressed_data = compressor.flush

  path = File.join(prefix, "#{entry.name}.bz2")
  puts "Storing '#{path}' on S3..."

  AWS::S3::S3Object.store(path, compressed_data, bucket)
end

puts "Done uploading to S3."
