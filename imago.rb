# **Imago** is a simple service to return website thumbnails.

### Setup
###### Requires

# Write out all requires from gems.
%w(rubygems sinatra imgkit digest/md5 haml redis open-uri RMagick json airbrake
  newrelic_rpm sinatra/jsonp timeout fog connection_pool).each { |g| require g }

# Require the app configs.
require_relative 'config'
include Magick

### Public Routes
###### "GET" /get_image?
#
# `/get_image?`
#
# Takes a list of params.
#
# * `website`: [REQUIRED] the website you wish to screenshot.
#    Website should be URL encoded
#    (e.g. http://www.example.com/test?1 becomes
#    http%3A%2F%2Fwww.example.com%2Ftest%3F1).
#    http/https optional.
#
# * `width`: [REQUIRED] the width of the screenshot. (e.g. 600)
#
# * `height`: [REQUIRED] the height of the screenshot. (e.g. 600)
#
# * `format`: [OPTIONAL] the format to respond with.
#    Accepted values are html, json, and image. Defaults to json.
#    Use image to inline images `<img src="/get_image?format=image" />`.
#
# _example_: 
# `/get_image?website=www.example.com&width=600&height=600&format=json`
get '/get_image?' do
  url = build_url(params['website']) || ''
  link = get_image_link(url)
  respond(link, url)
end

### Private Methods
private

###### get_image_link
#
# * `url`: the url of the website to image.
#
# Create the image and upload it. Return the link to the image
def get_image_link(url)
  return not_found_link unless valid?(params)

  # Hash the params to get the filename and the key for redis.
  name = Digest::MD5.hexdigest(
    "#{params['website']}_#{params['width']}_#{params['height']}"
  )

  # Try to lookup the hash to see if this image has been created before
  link = $redis.with { |conn| conn.get(name) }
  unless link
    begin
      # keep super slow sites from taking forever.
      Timeout.timeout(20) do
        # Generate the image.
        img = generate_image(url)
        # Store the image on s3.
        send_to_s3(img, name)
      end

      # Create the link url.
      link = "#{ENV['IMAGO_BASE_LINK_URL']}#{name}.jpg"
      save_to_redis(name, link)
    # return a 'not found' link if something goes wrong.
    rescue StandardError => e
      logger.error "Rescued Error Creating and Uploading Image: #{e}"
      link = not_found_link
      save_to_redis(name, link, 300)
    end
  end

  link
end

###### respond
#
# * `link`: the final link to the image.
#
# * `url`: the url the image was created from.
#
# Respond to request
def respond(link, url)
  case params['format']
  # Handle format = html
  when 'html'
    return haml :main, locals: { link: link }
  # Handle format = image
  when 'image'
    link.sub!('https://', 'http://')
    uri = URI(link)

    head = Net::HTTP.start(uri.host, uri.port) do |http|
      http.head(uri.request_uri)
    end

    headers 'Content-Type' => 'image/jpeg'
    headers 'Cache-Control' => 'max-age=2592000, no-transform, public'
    headers 'Expires' => 'Thu, 29 Sep 2022 01:22:54 GMT+00:00'

    return stream do |out|
      Net::HTTP.get_response(uri) do |f|
        f.read_body { |ch| out << ch }
      end
    end
  # Handle no format or format = json.
  else
    content_type :json
    return JSONP({ link: link, website: url }) # JSONP is an alias for jsonp method
  end
end

###### valid?
#
# * `params`: the params that were sent with the request.
#
# Validate the params sent with the request.
def valid?(params)
  # Make sure the website is a passed in param.
  unless params['website'] && given?(params['website'])
    return false
  end

  # Make sure the width is a passed in param.
  unless params['width'] && given?(params['width'])
    return false
  end

  # Make sure the height is a passed in param.
  unless params['height'] && given?(params['height'])
    return false
  end

  true
end

###### given?
#
# * `field`: the param field to check.
#
# Check that a field is not empty
def given?(field)
  !field.empty?
end

###### send_to_s3
#
# * `img`: the tmp path to the image file.
#
# * `name`: the name to use for the file.
#
# Store the image on s3.
def send_to_s3(img, name)
  s3_directory.files.create({
    key: "#{name}.jpg",
    body: img,
    public: true
  })
end

###### generate_image
#
# * `url`: the url of the website to thumbnail. (http://www.example.com)
#
# Grab the website image, resize with rmagick and return the image blob.
def generate_image(url)
  # Capture the screenshot
  kit = IMGKit.new(url, quality: 90, width: 1280, height: 720)

  # Resize the screengrab using rmagick
  Image.from_blob(kit.to_img(:jpg)).first.
    resize_to_fill!(params['width'].to_i, params['height'].to_i).to_blob
end

###### build_url
#
# * `website`: the website to build a working url for.
#
# Build a usable url from the website param
def build_url(website)
  begin
    decoded_url = URI::decode(website)
    if decoded_url[/^https?/]
      url = decoded_url
    else
      url = "http://#{decoded_url}"
    end
    url
  rescue StandardError => e
    nil
  end
end

###### not_found_link
#
# The link to return if something goes wrong
def not_found_link
  @not_found_url ||= "#{ENV['IMAGO_BASE_LINK_URL']}not_found.jpg"
end

###### save_to_redis
#
# * `key`: the key for redis.
#
# * `value`: the value to save in redis.
#
# * `time`: how long to store the value in redis. defaults 2 weeks
#
# Save the image link to redis
def save_to_redis(key, value, time=1209600)
  $redis.with do |conn|
    conn.set key, value
    conn.expire key, time
  end
end

###### s3_directory
#
# Get the s3 bucket object
def s3_directory
  @s3directory ||= s3_connection.directories.get(ENV['IMAGO_S3_BUCKET'])
end

###### s3_connection
#
# Get the s3 connection
def s3_connection
  @s3connection ||= connect_to_s3
end

###### connect_to_s3
#
# Handle connection to s3 with Fog
def connect_to_s3
  config = {
    provider: 'AWS',
    aws_access_key_id: ENV['IMAGO_S3_KEY'],
    aws_secret_access_key: ENV['IMAGO_S3_SECRET'],
    path_style: true
  }
  Fog::Storage.new(config)
end
