# be sure to create a config.yml file from the example and then run with ruby speedtest.rb

require 'json'
require 'csv'
require 'twitter'
require 'yaml'

config = YAML.load_file("./config.yml")

# write a header if we need one
unless File.exist? config["output_filename"]
  CSV.open(config["output_filename"], 'w') { |csv| csv << ['test_datetime','test_time (24 hr)', 'download_speed (mbps)', 'upload_speed (mbps)', 'packet_loss (%)', 'server', 'location', 'ping_time (ms)'] } if save_results
end

# configure twitter client
client = Twitter::REST::Client.new do |twitter_config|
  twitter_config.consumer_key        = config["consumer_key"]
  twitter_config.consumer_secret     = config["consumer_key_secret"]
  twitter_config.access_token        = config["access_token"]
  twitter_config.access_token_secret = config["access_token_secret"]
end

test_datetime = Time.now
test_time = test_datetime.strftime("%H:%M") # get 24 hour time only

puts "Running speedtest at #{test_datetime}"
output = `speedtest -f json` # use speedtest client to get results (note: returns results in bytes per second)
results = JSON.parse(output)
tweet_message = nil

if results['type'] == 'result' # successful test!

  download_speed = (results['download']['bandwidth'] / 125000.0).round(2)  # convert from bytes per second to mbps
  upload_speed = (results['upload']['bandwidth'] / 125000.0).round(2) # convert from bytes per second to mbps
  packet_loss = results['packetLoss']&.round(2) # returns nil sometimes, so guard against this
  server = results['server']['name']
  location = results['server']['location']
  ping_time = results['ping']['latency']

  puts "...success:  Down: #{download_speed}, Up: #{upload_speed}"

  if config["save_results"]
    puts "...saving results to #{config["output_filename"]}"
    CSV.open(config["output_filename"], 'a+') { |csv| csv << [test_datetime,test_time, download_speed, upload_speed, packet_loss, server, location, ping_time] }
  end

  if (download_speed < config["download_minimum"]) || (upload_speed < config["upload_minimum"])
    tweet_message = "Not looking so great :(  Our current Comcast @Xfinity internet speeds as of #{test_datetime}:  Download is #{download_speed} mbps and upload is #{upload_speed} mbps. Our plan is #{config["plan_down"]} down/#{config["plan_up"]} up."
  end

elsif results['error'] # speedtest-cli returned an error

  tweet_message = "Possibly slow or so broken that we couldn't run the speed test. Error reported by speedtest-cli is #{results['error']}.  Our plan is #{config["plan_down"]} down/#{config["plan_up"]} up."
  puts "...error: #{results['error']}"

else # we shouldn't get here unless something is really broken, like we couldn't even make a request to speedtest-cli...so unlikely tweeting will work either

  puts '...error: unknown reasons'

end

if config["tweet_results"] && tweet_message
  client.update(tweet_message)
  puts '...tweeting results'
end
