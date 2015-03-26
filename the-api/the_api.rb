Bundler.require

module TheApi
  module ApiSupport
    def self.included(base)
      base.send(:extend, ClassMethods)
      base.send(:format, :json)
      base.send(:prefix, :api)
    end

    module ClassMethods
      # format :json
      # prefix :api
    end
  end

  module Version2
    module Hoppy
      def self.included(base)
        base.send(:version, 'v2', using: :accept_version_header)
        base.send(:helpers, InstanceMethods)
      end

      module InstanceMethods
        def connection
          unless @connection.present?
            @connection = Bunny.new "amqp://localhost:5672"
            @connection.start
          end
          @connection
        end

        def channel
          @channel ||= connection.create_channel
        end
      end
    end

    class Direct < Grape::API
      include Hoppy

      resource :benefits do
        get do
          exchange = channel.default_exchange
          corr_id = SecureRandom.uuid

          that = Class.new do
            attr_accessor :response, :correlation_id
            attr_reader :lock, :condition

            def initialize
              @lock = Mutex.new
              @condition = ConditionVariable.new
            end
          end.new

          reply_queue = channel.queue("", :exclusive => true)
          reply_queue.subscribe do |di, m, p|
            if m[:correlation_id] == that.correlation_id
              that.response = p
              that.lock.synchronize{ that.condition.signal }
            end
          end

          puts "publishing #{corr_id}"
          exchange.publish("benefits-direct", routing_key: "request.#{corr_id}", correlation_id: corr_id, reply_to: reply_queue.name)
          that.lock.synchronize{ that.condition.wait(that.lock) }
          that.response
        end
      end
    end

    class PubSub < Grape::API
      include Hoppy

      resource :benefits do
        get do
          exchange = channel.topic "benefits", auto_delete: true, durable: true
          queue = channel.queue("benefits", auto_delete: true, durable: false)
          corr_id = SecureRandom.uuid
          @result = nil

          begin
            key = "response.#{corr_id}"
            puts "binding to #{key}"
            binding = queue.bind(exchange, routing_key: key)
            consumer = binding.subscribe do|di, m, p|
              puts "RCVD #{m} | #{p}"
              @result = p
            end
            puts "consumer: #{consumer}"
            puts "current result: #{@result}"

            exchange.publish("", routing_key: "request.#{corr_id}")

            unless @result.present?
              loop do
                sleep(0.2)
                puts "tick #{corr_id}: result \"#{@result}\""
                break if @result.present?
              end
            end
            return @result
          ensure
            queue.unbind(exchange)

            @result = nil
          end
        end
      end
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

  class API < Grape::API
    include ApiSupport
    mount TheApi::Version1
    # mount TheApi::Version2::PubSub
    mount TheApi::Version2::Direct
  end

end
