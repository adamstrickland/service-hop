Bundler.require

module TheApi
  class API < Grape::API
    version 'v1', using: :header, vendor: 'wellmatch'
    format :json
    prefix :api

    namespace :http do
      resource :benefits do
        get do
          host = 'http://localhost:9292'
          endpoint = "/api/benefits"
          Faraday.new(url: host).get(endpoint).body
        end
      end
    end

    namespace :bunny do
      resource :benefits do
        get do
          conn = Bunny.new "amqp://localhost:5672"
          conn.start
          channel = conn.create_channel
          exchange = channel.topic "benefits", auto_delete: true, durable: true
          queue = channel.queue("benefits", auto_delete: true, durable: false)
          corr_id = SecureRandom.uuid
          result = nil

          queue.bind(exchange, routing_key: "response.#{corr_id}").subscribe do|di, m, p|
            puts "RCVD #{m} | #{p}"
            result = p
          end

          exchange.publish("", routing_key: "request.#{corr_id}")

          loop do
            sleep(0.2)
            break if result.present?
          end
          result
        end
      end
    end
  end
end
