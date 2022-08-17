# frozen_string_literal: true

module Konfipay
  module Operations
    class Base
      def initialize(config = nil, client = nil)
        @config = (config || Konfipay.configuration)
        @client = (client || Konfipay::Client.new(@config))
      end

      def logger
        @config&.logger
      end

      # rubocop:disable Layout/LineLength
      def parse_pain_status(data)
        # Copied from https://portal.konfipay.de/api-docs/index.html#tag/Payment-SEPA/paths/~1api~1v5~1Payment~1Sepa~1Pain/post
        # May 2022, API version 5
        # KON_REJECTED - The file was rejected by konfipay. The reason is stated in the element errorItem. The file will not be processed. This status is final.
        # KON_ACCEPTED_AND_QUEUED - The file was accepted by konfipay. It is queued for further processing.
        # FIN_UPLOAD_SUCCEEDED - The file was successfully uploaded to the financial institution. The timestamp is stated in the element uploadTimestamp
        # FIN_UPLOAD_FAILED - The file was rejected by the financial institution during the upload process. The reason is stated in the errorItem element. This status is final.
        # FIN_UPLOAD_UNCLEAR - Its not clear if the file was uploaded successfully due to an unexpected error. konfipay will try to determin the actual status of the file. Please check the status frequently as it may change.
        # FIN_VEU_FORWARDED - The file was forwarded for signing within the distributed electronic signature process.
        # FIN_VEU_CANCELED - The file was canceled by an authorized person during the distributed electronic signature process. This status is final.
        # FIN_ACCEPTED - The financial institution has successfully completed all EBICS processing steps. This is not a confirmation that the file is being processed by the financial institution, but that the technical process of submission has been completed successfully. This status is not final.
        # FIN_PARTIALLY_ACCEPTED - The financial institution has sucessfully completed all EBICS processing steps, but only a part of the payments were accepted. This status is final.
        # FIN_CONFIRMED - The financial institution has confirmed the execution of the orders contained in the file. This status is final.
        # FIN_REJECTED - The financial institution was not able to complete all EBICS processing steps. The file will not be processed. Details are stated in the elements reasonCode, reason, and additionalInformation. This status is final.

        status = data['paymentStatusItem']['status']

        final, success = *case status
                          when 'KON_REJECTED', 'FIN_UPLOAD_FAILED', 'FIN_VEU_CANCELED', 'FIN_REJECTED'
                            [true, false]
                          when 'KON_ACCEPTED_AND_QUEUED', 'FIN_UPLOAD_SUCCEEDED', 'FIN_VEU_FORWARDED'
                            [false, true]
                          when 'FIN_UPLOAD_UNCLEAR'
                            [false, false]
                          # Note that the two "_ACCEPTED" states are not as "final" as the FIN_CONFIRMED state according to the Konfipay docs.
                          # However, we can't currently get the FIN_CONFIRMED state - it's unclear if this is normal or due to configuration issues
                          # at the bank or at Konfipay. But in testing, these have always been final "enough" and the transactions got executed.
                          when 'FIN_PARTIALLY_ACCEPTED', 'FIN_ACCEPTED', 'FIN_CONFIRMED'
                            [true, true]
                          else
                            raise "Unknown payment status #{status.inspect} ?!"
                          end

        {
          'final' => final,
          'success' => success,
          'data' => data
        }
      end
      # rubocop:enable Layout/LineLength
    end
  end
end
