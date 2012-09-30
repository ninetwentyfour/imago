IMGKit.configure do |config|
  config.wkhtmltoimage = settings.root.join('bin', 'wkhtmltoimage-amd64').to_s if ENV['RACK_ENV'] == 'production'
end