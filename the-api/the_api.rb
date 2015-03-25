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

  class Version2 < Grape::API
    version 'v2', using: :accept_version_header

    resource :benefits do
      get do
        conn = Bunny.new "amqp://localhost:5672"
        conn.start
        channel = conn.create_channel
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
    mount TheApi::Version2
  end

end
