#### Requires

# Write out all requires from gems
%w(rubygems sinatra imgkit digest/md5 haml redis open-uri RMagick json airbrake newrelic_rpm sinatra/jsonp timeout fog connection_pool).each { |g| require g }

# require the app configs
require_relative 'config'
include Magick

#### GET /get_image?

# `/get_image?` takes a list of params.
# The list of params are (all are required):
#
# * `website`: the url you wish to screenshot. Do not include http/https.
#    url should be encoded. (e.g. www.example.com)
#
# * `width`: the width of the screen shot. (e.g. 600)
#
# * `height`: the height of the screenshot. (e.g. 600)
#
# * `format`: the format to respond with.
#    Accepted values are html, json, and image.
#    Use image to inline images (e.g. `<img src="/get_image?format=image" />`)
#
# _EXAMPLE_:
#
# /get_image?website=www.example.com&width=600&height=600&format=json
get '/get_image?' do
  url = build_url(params['website']) || ''
  link = get_image_link(url)
  respond(link, url)
end


private

#### get_image_link
#
# * `url`: the url of the website to image.
#
# Create the image and upload it. Return the link to the image
def get_image_link(url)
  return "#{settings.base_link_url}not_found.jpg" unless validate(params).empty?

  # Hash the params to get the filename and the key for redis
  name = Digest::MD5.hexdigest(
    "#{params['website']}_#{params['width']}_#{params['height']}"
  )

  # Try to lookup the hash to see if this image has been created before
  link = $redis.with { |conn| conn.get(name) }
  unless link
    begin
      # keep super slow sites from taking forever
      Timeout.timeout(20) do
        # Generate the image.
        img = generate_image(url)
        # Store the image on s3.
        send_to_s3(img, name)
      end

      # Create the link url.
      link = "#{settings.base_link_url}#{name}.jpg"
      save_to_redis(name, link)
    rescue Exception => exception
      logger.error "Rescued Error Creating and Uploading Image: #{exception}"
      link = "#{settings.base_link_url}not_found.jpg"
      save_to_redis(name, link, 300)
    end
  end

  link
end

#### respond
#
# * `link`: the final link to the image.
#
# * `params`: the params that were sent with the request.
#
# Respond to request
def respond(link, url)
  case params['format']
  when 'html'
    haml :main, locals: { link: link }
  when 'image'
    # TODO: do all of this in a begin block.
    # Do a send_file with a local copy of not found if fail
    link.sub!('https://', 'http://')
    uri = URI(link)

    # get only header data
    head = Net::HTTP.start(uri.host, uri.port) do |http|
      http.head(uri.request_uri)
    end

    # set headers accordingly (all that apply)
    headers 'Content-Type' => head['Content-Type']
    headers 'Cache-Control' => 'max-age=2592000, no-transform, public'
    headers 'Expires' => 'Thu, 29 Sep 2022 01:22:54 GMT+00:00'

    # stream back the contents
    stream do |out|
      Net::HTTP.get_response(uri) do |f|
        f.read_body { |ch| out << ch }
      end
    end
  else
    # Return json if no format or format = json.
    content_type :json
    data = { :link => link, :website => url }
    JSONP data      # JSONP is an alias for jsonp method
  end
end

#### validate
#
# * `params`: the params that were sent with the request.
#
# Validate the params sent with the request.
def validate(params)
  errors = {}

  # Make sure the website is a passed in param.
  unless params['website'] && given?(params['website'])
    errors['website']   = 'This field is required'
  end

  # Make sure the width is a passed in param.
  unless params['width'] && given?(params['width'])
    errors['width']   = 'This field is required'
  end

  # Make sure the height is a passed in param.
  unless params['height'] && given?(params['height'])
    errors['height']   = 'This field is required'
  end

  # Make sure the format is a passed in param.
  unless params['format'] && given?(params['format'])
    errors['format']   = 'This field is required'
  end

  errors
end

#### given?
#
# * `field`: the param field to check.
#
# Check that a field is not empty
def given?(field)
  !field.empty?
end

#### send_to_s3
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

#### generate_image
#
# * `url`: the url of the website to thumbnail. (http://www.example.com)
#
# Grab the website image, resize with rmagick and return the image blob.
def generate_image(url)
  # begin
  #   fork_to(20) do
      # Capture the screenshot
      kit = IMGKit.new(url, quality: 90, width: 1280, height: 720)

      # Resize the screengrab using rmagick
      Image.from_blob(kit.to_img(:jpg)).first.
        resize_to_fill!(params['width'].to_i, params['height'].to_i).to_blob
    end
  # rescue Timeout::Error
  #   raise 'SubprocessTimedOut'
  # end
end

#### build_url
#
# * `website`: the website to build a working url for.
#
# Build a usable url from the website param
def build_url(website)
  decoded_url = URI::decode(website)
  if decoded_url[/^https?/]
    url = decoded_url
  else
    url = "http://#{decoded_url}"
  end
  url
end

# # pulled from http://aphyr.com/posts/214-unsafe-thread-concurrency-with-fork
# def fork_to(timeout = 4)
#   r, w, pid = nil, nil, nil
#   begin
#     # Open pipe
#     r, w = IO.pipe

#     # Start subprocess
#     pid = fork do
#       # Child
#       begin
#         r.close

#         val = begin
#           Timeout.timeout(timeout) do
#             # Run block
#             yield
#           end
#         rescue Exception => e
#           e
#         end

#         w.write Marshal.dump val
#         w.close
#       ensure
#         # YOU SHALL NOT PASS
#         # Skip at_exit handlers.
#         exit!
#       end
#     end

#     # Parent
#     w.close

#     Timeout.timeout(timeout) do
#       # Read value from pipe
#       begin
#         val = Marshal.load r.read
#       rescue ArgumentError => e
#         # Marshal data too short
#         # Subprocess likely exited without writing.
#         raise Timeout::Error
#       end

#       # Return or raise value from subprocess.
#       case val
#       when Exception
#         raise val
#       else
#         return val
#       end
#     end
#   ensure
#     if pid
#       Process.kill "TERM", pid rescue nil
#       Process.kill "KILL", pid rescue nil
#       Process.waitpid pid rescue nil
#     end
#     r.close rescue nil
#     w.close rescue nil
#   end
# end

#### save_to_redis
#
# * `key`: the key for redis.
#
# * `value`: the value to save in redis.
#
# * `time`: how long to store the value in redis. defaults 2 weeks
#
# Save the image link to redis
def save_to_redis(key, value, time=1209600)
  # Save in redis for re-use later.
  $redis.with do |conn|
    conn.set key, value
    conn.expire key, time
  end
end

#### s3_directory
#
# Get the s3 bucket object
def s3_directory
  @s3directory ||= s3_connection.directories.get(ENV['S3_BUCKET'])
end

#### s3_connection
#
# Get the s3 connection
def s3_connection
  @s3connection ||= connect_to_s3
end

#### connect_to_s3
#
# Handle connection to s3 with Fog
def connect_to_s3
  config = {
    provider: 'AWS',
    aws_access_key_id: ENV['S3_KEY'],
    aws_secret_access_key: ENV['S3_SECRET'],
    path_style: true
  }
  Fog::Storage.new(config)
end
