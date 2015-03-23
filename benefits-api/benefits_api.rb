require 'grape'

module BenefitsApi
  class API < Grape::API
    version 'v1', using: :header, vendor: 'wellmatch'
    format :json
    prefix :api

    resource :benefits do
      get do
        { id: 123456 }
      end
    end
  end
end
