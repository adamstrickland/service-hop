Bundler.require
require 'bunny'
require 'celluloid/io'
require 'celluloid/autostart'

class DirectRpcServer
  attr_reader :channel, :queue, :exchange

  def initialize
    @connection = Bunny.new
    @connection.start
    @channel = @connection.create_channel
    @exchange = @channel.default_exchange
  end

  def listen(queue, &block)
    @queue = @channel.queue(queue)
    puts " [x] Awaiting RPC requests on #{queue}"
    @queue.subscribe(block: true) do |_, properties, payload|
      response = if block
                   block.call(payload)
                 else
                   ""
                 end
      @exchange.publish(response.to_s, correlation_id: properties.correlation_id, routing_key: properties.reply_to)
    end
  end
end

class Fibonacci
  def self.call(n)
    case n.to_i
    when 0 then 0
    when 1 then 1
    else
      call(n - 1) + call(n - 2)
    end
  end
end

module BenefitsApi
  class API < Grape::API
    version 'v1', using: :header, vendor: 'wellmatch'
    format :json
    prefix :api

    resource :benefits do
      get do
        Fibonacci.((params[:n] || 30).to_i)
      end
    end

    class Handler
      include ::Celluloid::IO
      finalizer :shutdown
      def shutdown; end

      def initialize
        @impl = DirectRpcServer.new
        async.run
      end

      def run
        @impl.listen("benefits"){ |p| Fibonacci.(p.to_i) }
      end
    end

    Handler.new
  end
end
