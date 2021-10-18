module Konfipay
  module Jobs
    class FetchStatements
      include Sidekiq::Worker # TODO: This should be configurable

      def perform(which_ones, iban, callback_class, callback_method)
        client = Konfipay::Client.new
        list = case which_ones.to_s
        when 'new'
          client.new_statements
        else
          raise "not implemented yet"
        end

        # get each camt file and parse etc.
        # TODO: filter by iban?

        callback_class.constantize.send(callback_method, list)
      end
    end
  end
end
