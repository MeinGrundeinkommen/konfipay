# frozen_string_literal: true

module Konfipay
  module Operations
    class FetchStatements < Base
      # Returns transactions like this to the provided block:
      # [
      #
      #   {
      #     'amount_in_cents' => 1350,
      #     'currency' => 'EUR',
      #     'end_to_end_reference' => 'some-unique-ref-1', # not always present or unique
      #     'executed_on' => '2022-01-05', # the "booking date"
      #     'iban' => 'DE02300606010002474689', # name and iban are those of the debitor
      #                                         # if this is a debit or vice versa
      #     'name' => 'Unsere Organisation',
      #     'remittance_information' => 'text on bank statement',
      #     'type' => 'debit', # or "credit" - i.e. money going out from this account or money going in
      #     'additional_information' => 'Retourenbelastung', # basically a comment
      #     # The following fields are not nil only for "failed" debits (returns/reversals):
      #     'original_amount_in_cents' => 1100,
      #     'fees' => [
      #       {
      #         'amount_in_cents' => 250,
      #         'from_bic' => 'OURBIC123'
      #       }
      #     ],
      #     'reason_code' => 'AC04',
      #     'return_information' => 'Konto aufgelöst'
      #   },
      # ]
      #
      # Or an empty array if there is nothing new or matching.
      #
      # Transactions are retrieved based on camt53 files, i.e. the Konfipay API returns a file for
      # each banking day (if there are transactions booked on that date), but this returns all
      # contained transactions in a flat list - this also applies to collections of transactions
      # (for example for batched transfers/debits). The list is ordered by oldest files first, and within
      # the files by their appearance in the file. In other words, this returns transactions in
      # reverse chronological order, which is more natural for processing transactions if you just
      # iterate over the returned list.
      #
      # "mode" argument supports "new" and "history" currently.
      #
      # In "new" mode, transactions are retrieved and marked as "read" after successful
      # return of data, so transactions are only returned once.
      # Use {'mark_as_read' => false} in options argument to disable this behaviour (for testing etc.).
      #
      # Also note that transactions are marked as read _after_ the block returns, so if the block raises
      # an error, the next call will return the same data as before.
      #
      # In "history" mode, transactions between additionally needed "from" and "to" filter keys are returned,
      # they are not marked as read. "from" and "to" need to be strings in iso8601 format.
      #
      # Please note that from and to refer to the date of the camt53 file - this usually is provided a banking
      # day _after_ the contained transactions. I.e. if you want the transactions that were booked on
      # 2022-03-02 and 2022-03-03, filter by "from" => "2022-03-03" and "to" => "2022-03-04".
      #
      # Returns transaction from all configured accounts by default.
      # Filter by using {'iban' => 'an account iban'} as filters argument.
      def fetch(mode, filters = {}, options = {})
        raise 'You need to provide a block' unless block_given?

        logger&.info "#{mode.inspect} fetch operation started"

        filter_opts, mark_as_read = *prepare_options(mode, filters, options)

        docs = fetch_document_list(mode, filter_opts)

        if docs.nil? # you would think they could return an empty docs list...
          logger&.info "No #{mode} statement docs found, operation finished"
          yield []
          return
        end

        list = docs['documentItems']
        logger&.info "#{list.size} #{mode} statement docs found"

        # files come in newest-first, not very useful
        sorted_list = list.sort_by { |doc| Date.parse(doc['timestamp']) }

        r_ids_fetched, result = *fetch_and_parse_documents(sorted_list)

        yield result

        if mark_as_read
          acknowledge_camt_files(r_ids_fetched)
        else
          logger&.info 'Leaving files as unread'
        end

        logger&.info "#{mode.inspect} fetch operation finished"

        true
      end

      def prepare_options(mode, filters = {}, options = {})
        filter_opts = {}

        case mode
        when 'new'
          mark_as_read = true
          mark_as_read = false if options['mark_as_read'] == false
        when 'history'
          mark_as_read = false
          from_date = begin
            Date.parse(filters['from'])
          rescue Date::Error, TypeError
            nil
          end
          unless from_date.is_a?(Date)
            raise ArgumentError,
                  "'from' option #{filters['from'].inspect} is not present or not a valid iso8601 date!"
          end

          to_date = begin
            Date.parse(filters['to'])
          rescue Date::Error, TypeError
            nil
          end
          unless to_date.is_a?(Date)
            raise ArgumentError,
                  "'to' option #{filters['to'].inspect} is not present or not a valid iso8601 date!"
          end

          unless to_date >= from_date
            raise ArgumentError,
                  "#{from_date.inspect} has to be before or on same date as #{to_date.inspect}"
          end

          filter_opts['start'] = from_date.iso8601
          filter_opts['end'] = to_date.iso8601
        else
          raise "#{mode.inspect} mode is not implemented yet!"
        end

        iban = filters['iban'].presence
        filter_opts['iban'] = iban if iban

        [filter_opts, mark_as_read]
      end

      def fetch_document_list(mode, filter_opts = {})
        case mode
        when 'new'
          @client.new_statements(filter_opts)
        when 'history'
          @client.statement_history(filter_opts)
        else
          raise "#{mode.inspect} mode is not implemented yet!"
        end
      end

      def fetch_and_parse_documents(list)
        result = []
        r_ids_fetched = []

        list.each do |doc|
          r_id = doc['rId']
          raise unless r_id.present?

          r_ids_fetched << r_id
          logger&.info "fetching #{r_id.inspect}"
          camt = @client.camt_file(r_id, false)
          result += Konfipay::CamtDigester.new(camt).statements
        end
        [r_ids_fetched, result]
      end

      def acknowledge_camt_files(r_ids_fetched)
        r_ids_fetched.each do |r_id|
          logger&.info "Marking file #{r_id} as read"
          camt_status = @client.acknowledge_camt_file(r_id)
          raise "Tried to acknowledge #{r_id} but was still shown as new after!" if camt_status['isNew']
        end
      end
    end
  end
end
