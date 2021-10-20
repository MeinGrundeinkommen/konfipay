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
      def fetch(which_ones, filters = {})
        iban = filters['iban'].presence
        opts = {}
        opts['iban'] = iban if iban
        json = case which_ones
               when 'new'
                 @client.new_statements(opts)
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

          logger&.info "fetching #{r_id.inspect}"
          camt = @client.camt_file(r_id)
          camt.statements.each do |statement|
            # https://github.com/viafintech/camt_parser/blob/master/lib/camt_parser/general/entry.rb
            statement.entries.each do |entry|
              entry.transactions.each do |transaction|
                result << {
                  name: transaction.name,
                  iban: transaction.iban,
                  bic: transaction.bic,
                  type: entry.debit? ? 'debit' : 'credit',
                  amount_in_cents: entry.amount_in_cents,
                  currency: transaction.currency,
                  executed_on: entry.value_date.iso8601,
                  reference: transaction.remittance_information,
                  end_to_end_reference: transaction.end_to_end_reference,
                }.stringify_keys
              end
            end
          end
        end

        result
      end
    end
  end
end
