# frozen_string_literal: true

module Konfipay
  module Operations
    class FetchStatements < Base
      # Returns transactions like this:
      # [
      #   {
      #     "name": "John Doe",
      #     "iban": "DE02700205000007808005",
      #     "bic": "DEUS2149509",
      #     "type": "credit", # or "debit"
      #     "amount_in_cents": 10023,
      #     "currency": "EUR",
      #     "executed_on": "2016-05-02", # also called "value date"
      #     "reference": "Text on bank statement",
      #     "end_to_end_reference": "some-unique-ref-1", # not always present
      #   },
      # ]
      #
      # Or an empty array if there is nothing new or matching.
      #
      # "which_ones" argument only supports "new" currently.
      # In this "mode", transactions are retrieved and marked as "read" after successful
      # return of data, so transactions are only returned once.
      #
      # Use {'mark_as_read' => false} in options argument to disable this behaviour (for testing etc.).
      #
      # Returns transaction from all configured accounts by default.
      # Filter by using {'iban' => 'an account iban'} as filters argument.
      def fetch(which_ones, filters = {}, options = {})
        # TODO: Check that only known keys are in both hashes

        mark_as_read = true
        mark_as_read = false if options['mark_as_read'] == false

        iban = filters['iban'].presence
        filter_opts = {}
        filter_opts['iban'] = iban if iban

        json = case which_ones
               when 'new'
                 @client.new_statements(filter_opts)
               else
                 raise "#{which_ones.inspect} mode is not implemented yet!"
               end

        result = []

        if json.nil? # you would think they could return an empty json list...
          logger&.info "No #{which_ones} statement docs found"
          return result
        end

        list = json['documentItems']

        logger&.info "#{list.size} #{which_ones} statement docs found"

        list.each do |doc|
          r_id = doc['rId']
          raise unless r_id.present?

          logger&.info "fetching #{r_id.inspect} with mark_as_read = #{mark_as_read.inspect}"
          camt = @client.camt_file(r_id, mark_as_read)
          camt.statements.each do |statement|
            # https://github.com/viafintech/camt_parser/blob/master/lib/camt_parser/general/entry.rb
            statement.entries.each do |entry|
              entry.transactions.each do |transaction|
                result << {
                  name: transaction.name.presence,
                  iban: transaction.iban.presence,
                  bic: transaction.bic.presence,
                  type: transaction.debit? ? 'debit' : 'credit',
                  amount_in_cents: transaction.amount_in_cents,
                  currency: transaction.currency.presence,
                  executed_on: entry.value_date.iso8601,
                  reference: transaction.remittance_information.presence,
                  end_to_end_reference: transaction.end_to_end_reference.presence
                }.stringify_keys
              end
            end
          end
        end

        # TODO: Get each camt in readonly mode, pass out all results, and if that returns successfully,
        # loop over camt files and mark all as read

        result
      end
    end
  end
end
