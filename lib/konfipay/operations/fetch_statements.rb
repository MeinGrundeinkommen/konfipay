# frozen_string_literal: true

module Konfipay
  module Operations
    class FetchStatements < Base
      # Returns transactions like this to the provided block:
      # [
      #   {
      #     "name" => "John Doe",
      #     "iban" => "DE02700205000007808005",
      #     "bic" => "DEUS2149509",
      #     "type" => "credit", # or "debit"
      #     "amount_in_cents" => 10023,
      #     "currency" => "EUR",
      #     "executed_on" => "2016-05-02", # also called "value date"
      #     "reference" => "Text on bank statement",
      #     "end_to_end_reference" => "some-unique-ref-1", # not always present
      #   },
      # ]
      #
      # Or an empty array if there is nothing new or matching.
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

        r_ids_fetched, result = *fetch_and_parse_documents(list)

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
