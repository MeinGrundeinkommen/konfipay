module Konfipay
  module Operations
    class FetchStatements < Base
      def fetch(which_ones, filters = {})
        iban = filters["iban"].presence
        opts = {}
        opts["iban"] = iban if iban
        json = case which_ones
        when "new"
          @client.new_statements(opts)
        else
          raise "not implemented yet"
        end

        result = []

        if json.nil? # you would think they could return an empty json list...
          logger.info "No #{which_ones} statement docs found"
          return result
        end

        list = json["documentItems"]

        logger.info "#{list.size} #{which_ones} statement docs found"
        list.each do |doc|
          r_id = doc["rId"]
          raise unless r_id.present?
          logger.info "fetching #{r_id.inspect}"
          camt = @client.camt_file(r_id)
          # TODO: We need to understand the camt format better, the results don't seem to be right
          # but we need something with an end2endid...
          camt.statements.each do |statement|
            # https://github.com/viafintech/camt_parser/blob/master/lib/camt_parser/general/entry.rb
            statement.entries.each do |entry|
              entry.transactions.each do |transaction|
                result << {
                  amount_in_cents: entry.amount_in_cents,
                  end_to_end_id: transaction.end_to_end_reference
                }
              end
            end
          end
        end

        result
      end
    end
  end
end
