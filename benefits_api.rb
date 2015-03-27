Bundler.require
require 'bunny'
require 'celluloid/io'
require 'celluloid/autostart'

class RpcServer
  attr_reader :connection

  def initialize
    @connection = Bunny.new
    @connection.start
  end

  def channel
    @channel ||= connection.create_channel
  end

  def exchange
    @exchange ||= channel.default_exchange
  end
end

class DirectRpcServer < RpcServer
  def initialize
    super
  end

  def listen(queue, &block)
    @queue = channel.queue(queue)
    puts " [x] Awaiting RPC requests on #{queue}"
    @queue.subscribe(block: true) do |_, properties, payload|
      response = if block
                   block.call(payload)
                 else
                   ""
                 end
      exchange.publish(response.to_s, correlation_id: properties.correlation_id, routing_key: properties.reply_to)
    end
  end
end

class PubSubRpcServer < RpcServer
  def initialize(topic)
    @topic = topic
    super()
  end

  def exchange
    @exchange ||= channel.topic @topic
  end

  def listen(&block)
    queue = channel.queue(@topic)
    queue.bind(exchange, routing_key: "request.#").subscribe do |_, properties, payload|
      response = if block
                   block.call(payload)
                 else
                   ""
                 end
      queue.publish(response, routing_key: "response.#{properties.correlation_id}",
                              correlation_id: properties.correlation_id)
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
        async.run
      end
    end

    Class.new(Handler) do
      def run
        (@impl ||= DirectRpcServer.new).listen("benefits") do |p|
          Fibonacci.(p.to_i)
        end
      end
    end.new

    Class.new(Handler) do
      def run
        (@impl ||= PubSubRpcServer.new("benefits-pubsub")).listen do |p|
          Fibonacci.(p.to_i)
        end
      end
    end.new
  end
end
