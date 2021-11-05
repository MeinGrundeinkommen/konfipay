# frozen_string_literal: true

module Konfipay
  module Operations
    class FetchStatements < Base
      # Returns transactions like this to the provided block:
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
      #
      # In this "mode", transactions are retrieved and marked as "read" after successful
      # return of data, so transactions are only returned once.
      # Use {'mark_as_read' => false} in options argument to disable this behaviour (for testing etc.).
      #
      # Also note that transactions are marked as read _after_ the block returns, so if the block raises
      # an error, the next call will return the same data as before.
      #
      # Returns transaction from all configured accounts by default.
      # Filter by using {'iban' => 'an account iban'} as filters argument.
      def fetch(which_ones, filters = {}, options = {})
        # TODO: Check that only known keys are in both hashes
        raise 'You need to provide a block' unless block_given?

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
          yield result
          return
        end

        list = json['documentItems']
        r_ids_fetched = []

        logger&.info "#{list.size} #{which_ones} statement docs found"

        list.each do |doc|
          r_id = doc['rId']
          raise unless r_id.present?

          r_ids_fetched << r_id

          logger&.info "fetching #{r_id.inspect}"
          camt = @client.camt_file(r_id, false)
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

        yield result

        if mark_as_read
          r_ids_fetched.each do |r_id|
            logger&.info "Marking file #{r_id} as read"
            camt_status = @client.acknowledge_camt_file(r_id)
            raise "Tried to acknowledge #{r_id} but was still shown as new after!" if camt_status['isNew']
          end
        else
          logger&.debug 'Leaving files as unread'
        end

        true
      end
    end
  end
end
