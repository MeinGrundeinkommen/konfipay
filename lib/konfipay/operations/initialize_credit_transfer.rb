# frozen_string_literal: true

module Konfipay
  module Operations
    class InitializeCreditTransfer < Base
      # Starts a credit transfer (Überweisung) from one of our accounts to one or many recipients.

# x = {"debtor"=>{"name"=>"Mein Grundeinkommen e.V.", "iban"=>"DE49430609671165313801", "bic"=>nil},
#  "creditors"=>
#   [{"name"=>"Carrol Wiza",
#     "iban"=>"AT483200000012345864",
#     "bic"=>nil,
#     "amount_in_cents"=>100000,
#     "currency"=>"EUR",
#     "remittance_information"=>"Dein BGE in diesem Monat Viel Freude von Mein Grundeinkommen",
#     "end_to_end_reference"=>"BGE-0012-02",
#     "execute_on"=>"2022-10-03"},
#    {"name"=>"Josue Bruen",
#     "iban"=>"AT483200000012345864",
#     "bic"=>nil,
#     "amount_in_cents"=>100000,
#     "currency"=>"EUR",
#     "remittance_information"=>"Kinder-BGE in diesem Monat Viel Freude von Mein Grundeinkommen",
#     "end_to_end_reference"=>"BGE-0013-02",
#     "execute_on"=>"2022-10-03"}]}
# Konfipay::Operations::InitializeCreditTransfer.new.submit(x, "bla")

      # "gid://mge/TransferCollection/2"


# <Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.003.03" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:iso:std:iso:20022:tech:xsd:pain.001.003.03 pain.001.003.03.xsd">
#   <CstmrCdtTrfInitn>
#     <GrpHdr>
#       <MsgId>SEPA-KING/320e3abca9a206ddf315b7</MsgId>
#       <CreDtTm>2022-05-17T17:59:15+02:00</CreDtTm>
#       <NbOfTxs>2</NbOfTxs>
#       <CtrlSum>2000.00</CtrlSum>
#       <InitgPty>
#         <Nm>Mein Grundeinkommen e.V.</Nm>
#       </InitgPty>
#     </GrpHdr>
#     <PmtInf>
#       <PmtInfId>SEPA-KING/320e3abca9a206ddf315b7/1</PmtInfId>
#       <PmtMtd>TRF</PmtMtd>
#       <BtchBookg>true</BtchBookg>
#       <NbOfTxs>2</NbOfTxs>
#       <CtrlSum>2000.00</CtrlSum>
#       <PmtTpInf>
#         <SvcLvl>
#           <Cd>SEPA</Cd>
#         </SvcLvl>
#       </PmtTpInf>
#       <ReqdExctnDt>2022-10-03</ReqdExctnDt>
#       <Dbtr>
#         <Nm>Mein Grundeinkommen e.V.</Nm>
#       </Dbtr>
#       <DbtrAcct>
#         <Id>
#           <IBAN>DE49430609671165313801</IBAN>
#         </Id>
#       </DbtrAcct>
#       <DbtrAgt>
#         <FinInstnId>
#           <Othr>
#             <Id>NOTPROVIDED</Id>
#           </Othr>
#         </FinInstnId>
#       </DbtrAgt>
#       <ChrgBr>SLEV</ChrgBr>
#       <CdtTrfTxInf>
#         <PmtId>
#           <EndToEndId>BGE-0012-02</EndToEndId>
#         </PmtId>
#         <Amt>
#           <InstdAmt Ccy="EUR">1000.00</InstdAmt>
#         </Amt>
#         <Cdtr>
#           <Nm>Carrol Wiza</Nm>
#         </Cdtr>
#         <CdtrAcct>
#           <Id>
#             <IBAN>AT483200000012345864</IBAN>
#           </Id>
#         </CdtrAcct>
#         <RmtInf>
#           <Ustrd>Dein BGE in diesem Monat Viel Freude von Mein Grundeinkommen</Ustrd>
#         </RmtInf>
#       </CdtTrfTxInf>
#       <CdtTrfTxInf>
#         <PmtId>
#           <EndToEndId>BGE-0013-02</EndToEndId>
#         </PmtId>
#         <Amt>
#           <InstdAmt Ccy="EUR">1000.00</InstdAmt>
#         </Amt>
#         <Cdtr>
#           <Nm>Josue Bruen</Nm>
#         </Cdtr>
#         <CdtrAcct>
#           <Id>
#             <IBAN>AT483200000012345864</IBAN>
#           </Id>
#         </CdtrAcct>
#         <RmtInf>
#           <Ustrd>Kinder-BGE in diesem Monat Viel Freude von Mein Grundeinkommen</Ustrd>
#         </RmtInf>
#       </CdtTrfTxInf>
#     </PmtInf>
#   </CstmrCdtTrfInitn>
# </Document>

# TODO: What are those weird group headers? Get rid of it and add gem info?

# This always returns a hash with these fields:
#
# "final" => final,
# "success" => success,
# "data" => { "SEPA builder error" => e.inspect }
#
# TODO: Explain
#
# or it can raise a connection error exception.

      def submit(payment_data, transaction_id)
 #       pp(transaction_id)
        pp(payment_data)
        # TODO: validate payment data again?

        xml = nil
        begin
          xml = Konfipay::PainBuilder.new(payment_data, transaction_id).credit_transfer_xml # here comes the pain
        rescue ArgumentError => e
          return {
            "final" => true,
            "success" => false,
            "data" => {
              "SEPA builder error" => e.inspect
            }
          }
        end
        puts xml
        client = Konfipay::Client.new
        data = nil
        begin
          data = client.submit_pain_file(xml)
        rescue Konfipay::Client::Unauthorized, Konfipay::Client::BadRequest => x
          return {
            "final" => true,
            "success" => false,
            "data" => {
              "error_class" => x.class.name,
              "message" => x.message
            }
          }
        end

        parse_pain_status(data)
      end
    end
  end
end
