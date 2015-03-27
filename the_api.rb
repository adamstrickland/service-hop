Bundler.require
require 'thread'
require 'securerandom'

module TheApi
  module ApiSupport
    def self.included(base)
      base.send(:extend, ClassMethods)
      base.send(:format, :json)
      base.send(:prefix, :api)
    end

    module ClassMethods
    end
  end

  class Version1 < Grape::API
    version 'v1', using: :accept_version_header

    resource :benefits do
      get do
        host = 'http://localhost:9292'
        n = params[:n] || 30
        endpoint = "/api/benefits"
        Faraday.new(url: host).get(endpoint, {n: n}).body.to_i
      end
    end
  end

  class RpcClient
    attr_accessor :connection, :response
    attr_reader :lock, :condition

    def initialize(connection)
      @connection = connection
      @lock = Mutex.new
      @condition = ConditionVariable.new
    end

    def channel
      @channel ||= connection.create_channel
    end

    def exchange
      @exchange ||= channel.default_exchange
    end

    def call_id
      @call_id ||= ::SecureRandom.uuid.to_s
    end
  end

  class DirectRpcClient < RpcClient
    attr_reader :reply_queue

    def initialize(connection, server_queue)
      puts "setup connection"
      super(connection)

      @server_queue = server_queue
      @reply_queue = channel.queue("", exclusive: true)
      that = self

      puts "subscirbing to reply queue"
      @reply_queue.subscribe do |_, properties, payload|
        if properties[:correlation_id] == that.call_id
          that.response = payload.to_i
          that.lock.synchronize{ that.condition.signal }
        end
      end
    end

    def call(&block)
      puts "building payload"
      payload = if block
                  block.call
                else
                  ""
                end
      puts "publishing"
      exchange.publish(payload.to_s, routing_key: @server_queue,
                                     correlation_id: call_id,
                                     reply_to: @reply_queue.name)
      lock.synchronize{ condition.wait(lock) }
      response
    end
  end

  module Hoppy
    def self.included(base)
      base.send(:helpers, Helpers)
    end

    module Helpers
      def connection
        unless @connection.present?
          @connection = Bunny.new(automatically_recover: false)
          @connection.start
        end
        @connection
      end
    end
  end

  class Version2 < Grape::API
    include Hoppy

    version 'v2', using: :accept_version_header

    helpers do
      def rpc(queue, &block)
        puts "init client"
        client = TheApi::DirectRpcClient.new(connection, queue)
        puts "call client"
        client.call(&block)
      end
    end

    resource :benefits do
      get do
        puts "GET benefits"
        rpc("benefits"){ params[:n] || 30 }
      end
    end
  end

  class PubSubRpcClient < RpcClient
    def initialize(connection, topic)
      super(connection)

      @topic = topic

      that = self

      # @reply_queue = channel.queue(@topic, exclusive: true)
      @reply_queue = channel.queue(@topic)
      @reply_queue.bind(exchange, routing_key: "response.#{call_id}").subscribe do |_, properties, payload|
        if properties[:correlation_id] == that.call_id
          that.response = payload.to_i
          that.lock.synchronize{ that.condition.signal }
        end
      end
    end

    def call(&block)
      payload = if block
                  block.call
                else
                  ""
                end
      exchange.publish(payload.to_s, routing_key: "request.#{call_id}",
                                     correlation_id: call_id,
                                     reply_to: @reply_queue.name)
      lock.synchronize{ condition.wait(lock) }
      response
    end

    def exchange
      @exchange ||= channel.topic(@topic)
    end
  end

  class Version3 < Grape::API
    include Hoppy

    version 'v3', using: :accept_version_header

    helpers do
      def rpc(queue, &block)
        client = TheApi::PubSubRpcClient.new(connection, queue)
        client.call(&block)
      end
    end

    resource :benefits do
      get do
        rpc("benefits-pubsub"){ params[:n] || 30 }
      end
    end
  end

  class API < Grape::API
    include ApiSupport
    mount TheApi::Version1
    mount TheApi::Version2
    mount TheApi::Version3
  end
end
