require 'simplecov'
require 'coveralls'
require "fakeredis"

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start 'rails' do
  add_filter 'config.rb' # dont track code coverage of config
end

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
      aws_access_key_id: ENV['IMAGO_S3_KEY'],
      aws_secret_access_key: ENV['IMAGO_S3_SECRET'],
      path_style: true
    })
    @s3_connection_double.directories.create({key: ENV['IMAGO_S3_BUCKET']})

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
      expect(valid?(params)).to eq true
    end

    it "requires a website" do
      params = {
        'width' => '600',
        'height' => '600',
        'format' => 'json'
      }
      expect(valid?(params)).to eq false
    end

    it "requires a non empty website" do
      params = {
        'website' => '',
        'width' => '600',
        'height' => '600',
        'format' => 'json'
      }
      expect(valid?(params)).to eq false
    end
    
    it "requires a width" do
      params = {
        'website' => 'www.travisberry.com',
        'height' => '600',
        'format' => 'json'
      }
      expect(valid?(params)).to eq false
    end

    it "requires a non empty width" do
      params = {
        'website' => 'www.travisberry.com',
        'width' => '',
        'height' => '600',
        'format' => 'json'
      }
      expect(valid?(params)).to eq false
    end
    
    it "requires a height" do
      params = {
        'website' => 'www.travisberry.com',
        'width' => '600',
        'format' => 'json'
      }
      expect(valid?(params)).to eq false
    end

    it "requires a non empty height" do
      params = {
        'website' => 'www.travisberry.com',
        'width' => '600',
        'height' => '',
        'format' => 'json'
      }
      expect(valid?(params)).to eq false
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
      expect(s3_directory.key).to eq @s3_connection_double.directories.get(ENV['IMAGO_S3_BUCKET']).key
    end

    it "#send_to_s3 uploads a file to amazon s3" do
      file = File.open('./spec/thug_life.jpeg')
      send_to_s3(file, 'test_file')

      s3_directory = @s3_connection_double.directories.get(ENV['IMAGO_S3_BUCKET'])
      uploaded_file = s3_directory.files.get('test_file.jpg')

      expect(uploaded_file.body).to eq File.read('./spec/thug_life.jpeg')
    end
  end

  describe '#save_to_redis' do
    it "should save to redis" do
      save_to_redis("example", "bar", 10)

      expect(@redis.get("example")).to eq "bar"
    end
  end

  describe '#not_found_link' do
    it "returns the not found link" do
      expect(not_found_link).to eq "#{ENV['IMAGO_BASE_LINK_URL']}not_found.jpg"
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

    it 'returns nil is no url is passed in' do
      expect(build_url(nil)).to eq nil
    end
  end
  
  describe 'http calls to our endpoint' do
    it "returns a json response for a url with no format" do
      get '/get_image?website=www.travisberry.com&width=320&height=200'
      expect(last_response).to be_ok
      expect(last_response.header['Content-Type']).to eq 'application/json'
      expect(last_response.body).to eq "{\"link\":\"#{ENV['IMAGO_BASE_LINK_URL']}6b3927a0e37512e2efa3b25cb440a498.jpg\",\"website\":\"http://www.travisberry.com\"}"
    end

    it "returns a json response for a valid url" do
      get '/get_image?website=www.travisberry.com&width=320&height=200&format=json'
      expect(last_response).to be_ok
      expect(last_response.header['Content-Type']).to eq 'application/json'
      expect(last_response.body).to eq "{\"link\":\"#{ENV['IMAGO_BASE_LINK_URL']}6b3927a0e37512e2efa3b25cb440a498.jpg\",\"website\":\"http://www.travisberry.com\"}"
    end
    
    it "returns an image response for a valid url" do
      get '/get_image?website=www.travisberry.com&width=320&height=200&format=image'
      expect(last_response).to be_ok
      expect(last_response.header['Content-Length'].to_i).to be > 0
      # last_response.header.delete("Content-Length") # remove the length, it fluctuates a bit
      expect(last_response.header['Cache-Control']).to eq 'max-age=2592000, no-transform, public'
      expect(last_response.header['Expires']).to eq 'Thu, 29 Sep 2022 01:22:54 GMT+00:00'
      expect(last_response.header['X-Content-Type-Options']).to eq 'nosniff'
      expect(last_response.header['Content-Type']).to eq 'image/jpeg'
    end
    
    it "returns a html response for a valid url" do
      get '/get_image?website=www.travisberry.com&width=320&height=200&format=html'
      expect(last_response).to be_ok
      expect(last_response.header['Content-Type']).to eq "text/html;charset=utf-8"
    end

    it "returns the not found url if an exception is raised" do
      app.any_instance.stub(:generate_image).and_raise("any error")
      get '/get_image?website=www.travisberry.com&width=320&height=200&format=json'
      expect(last_response).to be_ok
      expect(last_response.body).to eq "{\"link\":\"#{ENV['IMAGO_BASE_LINK_URL']}not_found.jpg\",\"website\":\"http://www.travisberry.com\"}"
    end

    it "returns the not found url no website is passed in" do
      get '/get_image?width=320&height=200&format=json'
      expect(last_response).to be_ok
      expect(last_response.body).to eq "{\"link\":\"#{ENV['IMAGO_BASE_LINK_URL']}not_found.jpg\",\"website\":\"\"}"
    end

    it "returns the not found url no width is passed in" do
      get '/get_image?website=www.travisberry.com&height=200&format=json'
      expect(last_response).to be_ok
      expect(last_response.body).to eq "{\"link\":\"#{ENV['IMAGO_BASE_LINK_URL']}not_found.jpg\",\"website\":\"http://www.travisberry.com\"}"
    end

    it "returns the not found url no height is passed in" do
      get '/get_image?website=www.travisberry.com&width=200&format=json'
      expect(last_response).to be_ok
      expect(last_response.body).to eq "{\"link\":\"#{ENV['IMAGO_BASE_LINK_URL']}not_found.jpg\",\"website\":\"http://www.travisberry.com\"}"
    end

    it "returns the not found url no params are passed in" do
      get '/get_image?'
      expect(last_response).to be_ok
      expect(last_response.body).to eq "{\"link\":\"#{ENV['IMAGO_BASE_LINK_URL']}not_found.jpg\",\"website\":\"\"}"
    end

    it "returns the link from redis if cached" do
      save_to_redis("6b3927a0e37512e2efa3b25cb440a498", "woohoo")
      get '/get_image?website=www.travisberry.com&width=320&height=200&format=json'
      expect(last_response).to be_ok
      expect(last_response.body).to eq "{\"link\":\"woohoo\",\"website\":\"http://www.travisberry.com\"}"
    end
  end
end
