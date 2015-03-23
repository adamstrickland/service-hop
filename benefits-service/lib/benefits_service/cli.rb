require 'thor'

module BenefitsService
  class Cli < ::Thor
    namespace :benefits_service

    desc "serve", "runs the server"
    def serve
      BenefitsService::Server.configure do |config|

      end.start
    end
  end
end
