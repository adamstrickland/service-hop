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
        endpoint = "/api/benefits"
        Faraday.new(url: host).get(endpoint).body
      end
    end
  end

  class DirectRpcClient
    attr_reader :reply_queue, :lock, :condition
    attr_accessor :response

    def initialize(channel, server_queue)
      @channel = channel
      @exchange = @channel.default_exchange
      @server_queue = server_queue
      @reply_queue = @channel.queue("", exclusive: true)
      @lock = Mutex.new
      @condition = ConditionVariable.new
      that = self

      @reply_queue.subscribe do |_, properties, payload|
        if properties[:correlation_id] == that.call_id
          that.response = payload.to_i
          that.lock.synchronize{ that.condition.signal }
        end
      end
    end

    def call_id
      @call_id ||= ::SecureRandom.uuid.to_s
    end

    def call(&block)
      payload = if block
                  block.call
                else
                  ""
                end
      @exchange.publish(payload.to_s, routing_key: @server_queue, correlation_id: call_id, reply_to: @reply_queue.name)
      lock.synchronize{ condition.wait(lock) }
      response
    end
  end

  class Version2 < Grape::API
    version 'v2', using: :accept_version_header

    helpers do
      def connection
        unless @connection.present?
          @connection = Bunny.new(automatically_recover: false)
          @connection.start
        end
        @connection
      end

      def channel
        @channel ||= connection.create_channel
      end

      def rpc(queue, &block)
        client = TheApi::DirectRpcClient.new(channel, queue)
        client.call(&block)
      end
    end

    resource :benefits do
      get do
        rpc("benefits"){ params[:n] || 30 }
      end
    end
  end

  class API < Grape::API
    include ApiSupport
    mount TheApi::Version1
    mount TheApi::Version2
  end
end
