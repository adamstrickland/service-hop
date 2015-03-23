require 'bunny'
require 'celluloid/io'
require 'celluloid/autostart'

module BenefitsService
  class Worker
    include Celluloid

    def handle(options = {})
      puts "HANDLING"
    end
  end

  class Server
    include ::Celluloid

    finalizer :shutdown

    def shutdown; end

    def self.configure
      self.new
    end

    def initialize
      @connection = Bunny.new("amqp://localhost:5672")
      @connection.start

      @channel = @connection.create_channel

      @exchange = @channel.topic "benefits", auto_delete: true, durable: true

      queue = @channel.queue("benefits", auto_delete: true, durable: false)

      queue.bind(@exchange, routing_key: 'request.#').subscribe do |di, m, p|
        corr_id = di.routing_key.split(/\./).last
        message = "OK #{corr_id}"
        puts message
        queue.publish("REPLY #{corr_id}", routing_key: "response.#{di.routing_key}")
      end

      super
    end

    def start
      loop {
        sleep(1)
      }
    end
  end
end
