require 'simplecov'
require 'coveralls'
require "fakeredis"

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start 'rails' do
  add_filter 'config.rb'
end
#
require File.join(File.dirname(__FILE__), '../imago.rb')
require 'rspec'
require 'rack/test'

set :environment, :test

describe 'Imago' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  before do
    Fog.mock!
    Fog::Mock.reset
    @s3_connection_double = Fog::Storage.new({
      provider: 'AWS',
      aws_access_key_id: ENV['S3_KEY'],
      aws_secret_access_key: ENV['S3_SECRET'],
      path_style: true
    })
    @s3_connection_double.directories.create({key: ENV['S3_BUCKET']})

    @redis = Redis.new
    @redis.flushall
  end

  describe 'validations' do
    
    it "validates good params" do
      params = {
        'website' => 'www.travisberry.com',
        'width' => '600',
        'height' => '600',
        'format' => 'json'
      }
      errors = validate(params)
      errors.should == {}
    end

    it "requires a website" do
      params = {
        'width' => '600',
        'height' => '600',
        'format' => 'json'
      }
      errors = validate(params)
      errors['website'].should == 'This field is required'
    end

    it "requires a non empty website" do
      params = {
        'website' => '',
        'width' => '600',
        'height' => '600',
        'format' => 'json'
      }
      errors = validate(params)
      errors['website'].should == 'This field is required'
    end
    
    it "requires a width" do
      params = {
        'website' => 'www.travisberry.com',
        'height' => '600',
        'format' => 'json'
      }
      errors = validate(params)
      errors['width'].should == 'This field is required'
    end

    it "requires a non empty width" do
      params = {
        'website' => 'www.travisberry.com',
        'width' => '',
        'height' => '600',
        'format' => 'json'
      }
      errors = validate(params)
      errors['width'].should == 'This field is required'
    end
    
    it "requires a height" do
      params = {
        'website' => 'www.travisberry.com',
        'width' => '600',
        'format' => 'json'
      }
      errors = validate(params)
      errors['height'].should == 'This field is required'
    end

    it "requires a non empty height" do
      params = {
        'website' => 'www.travisberry.com',
        'width' => '600',
        'height' => '',
        'format' => 'json'
      }
      errors = validate(params)
      errors['height'].should == 'This field is required'
    end    
  end    

  describe 's3' do
    it "#connect_to_s3 returns a fog object" do
      expect(connect_to_s3.methods).to eq @s3_connection_double.methods
    end

    it "#s3_connection returns a fog object" do
      expect(s3_connection.methods).to eq @s3_connection_double.methods
    end

    it "#s3_directory returns a fog object" do
      expect(s3_directory.key).to eq @s3_connection_double.directories.get(ENV['S3_BUCKET']).key
    end

    it "#send_to_s3 uploads a file to amazon s3" do
      file = File.open('./spec/thug_life.jpeg')
      send_to_s3(file, 'test_file')

      s3_directory = @s3_connection_double.directories.get(ENV['S3_BUCKET'])
      uploaded_file = s3_directory.files.get('test_file.jpg')

      expect(uploaded_file.body).to eq File.read('./spec/thug_life.jpeg')
    end
  end

  describe 'redis' do
    it "#save_to_redis should save to redis" do
      save_to_redis("example", "bar", 10)

      expect(@redis.get("example")).to eq "bar"
    end
  end

  describe '#not_found_link' do
    it "returns the not found link" do
      expect(not_found_link).to eq "#{ENV['BASE_LINK_URL']}not_found.jpg"
    end
  end

  describe '#build_url' do
    it 'returns a url with http added' do
      expect(build_url('www.example.com')).to eq 'http://www.example.com'
    end

    it 'returns an unmodified url if the url contains http' do
      expect(build_url('http://www.example.com')).to eq 'http://www.example.com'
    end

    it 'returns an unmodified url if the url contains https' do
      expect(build_url('https://www.example.com')).to eq 'https://www.example.com'
    end
  end
  
  describe 'http calls to our endpoint' do
    it "returns a json response for a url with no format" do
      get '/get_image?website=www.travisberry.com&width=320&height=200'
      last_response.should be_ok
      last_response.header["Content-Type"].should == "application/json;charset=utf-8"
      last_response.body.should == "{\"link\":\"#{ENV['BASE_LINK_URL']}6b3927a0e37512e2efa3b25cb440a498.jpg\",\"website\":\"http://www.travisberry.com\"}"
    end

    it "returns a json response for a valid url" do
      get '/get_image?website=www.travisberry.com&width=320&height=200&format=json'
      last_response.should be_ok
      last_response.header["Content-Type"].should == "application/json;charset=utf-8"
      last_response.body.should == "{\"link\":\"#{ENV['BASE_LINK_URL']}6b3927a0e37512e2efa3b25cb440a498.jpg\",\"website\":\"http://www.travisberry.com\"}"
    end
    
    it "returns an image response for a valid url" do
      get '/get_image?website=www.travisberry.com&width=320&height=200&format=image'
      last_response.should be_ok
      # puts last_response.header
      last_response.header.delete("Content-Length") # remove the length, it fluctuates a bit
      last_response.header.should == {"Content-Type"=>"image/jpeg", "Cache-Control"=>"max-age=2592000, no-transform, public", "Expires"=>"Thu, 29 Sep 2022 01:22:54 GMT+00:00", "X-Content-Type-Options"=>"nosniff"}
    end
    
    it "returns a html response for a valid url" do
      get '/get_image?website=www.travisberry.com&width=320&height=200&format=html'
      last_response.should be_ok
      last_response.header["Content-Type"].should == "text/html;charset=utf-8"
    end
  end
end
