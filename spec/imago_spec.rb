require File.join(File.dirname(__FILE__), '../imago.rb')
require 'rspec'
require 'rack/test'

set :environment, :test

describe 'Imago' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

    it "validates params" do
      params = {
        'website' => 'www.travisberry.com',
        'width' => '600',
        'height' => '600',
        'format' => 'json'
      }
      @errors = validate(params)
      @errors.should == {}
    end
    
    
    it "uploads a file to amazon s3" do
      file = './spec/thug_life.jpeg'
      send_to_s3(file, 'test_file').should_not be nil
    end
end