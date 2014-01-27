require 'json'

require 'stomp'
require 'trollop'

class NrPollerPoller

  # Initialize the poller

  def initialize(hostname, username, password)

    @hostname = hostname
    @username = username
    @password = password

    puts "Stomp consumer for Network Rail Open Data Distribution Service"

  end


  # Connect to the service and process messages

  def run

    client_headers = {
      "accept-version" => "1.1",
      "heart-beat" => "5000,10000",
      "client-id" => Socket.gethostname,
      "host" => @hostname
    }
    client_hash = {
      :hosts => [{
        :login => @username,
        :passcode => @password,
        :host => @hostname,
        :port => 61618 }
      ],
      :connect_headers => client_headers
    }

    client = Stomp::Client.new(client_hash)

    # Check we have connected successfully

    unless client.open?
      raise "Connection failed"
    end
    if client.connection_frame().command == Stomp::CMD_ERROR
      raise "Connect error: #{client.connection_frame().body}"
    end
    unless client.protocol == Stomp::SPL_11
      raise "Unexpected protocol level #{client.protocol}"
    end

    puts "Connected to #{client.connection_frame().headers['server']} server with STOMP #{client.connection_frame().headers['version']}"


    # Subscribe to the RTPPM topic and process messages
    subscription_options = {
      'id' => client.uuid(),
      'ack' => 'client',
      'activemq.subscriptionName' => Socket.gethostname + '-RTPPM'
    }

    client.subscribe("/topic/TRAIN_MVT_HF_TOC", subscription_options) do |msg|
      puts msg.body
      client.acknowledge(msg, msg.headers)
    end

    client.join


    # We will probably never end up here

    client.close
    puts "Client close complete"

  end

end

def parse_options
  opts = Trollop::options do
    opt(:config,
        'Configuration JSON file',
        :type => :string)
    opt(:username,
        'NROD username',
        :type => :string)
    opt(:hostname,
        'NROD hostname',
        :type => :string,
        :default => 'datafeeds.networkrail.co.uk')
    opt(:password,
        'NROD password',
        :type => :string)
  end

  if opts[:config]
    config_file = opts[:config]
    config = JSON.parse(IO.read(config_file), {symbolize_names: true})
    opts = opts.merge(config)
  end

  [:username, :password, :hostname].each do |option|
    unless opts[option]
      Trollop::die option, 'must be specified.'
    end
  end

  opts
end

def main
  opts = parse_options()
  e = NrPollerPoller.new opts[:hostname], opts[:username], opts[:password]
  e.run
end

if __FILE__ == $0
  main()
end

