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

      def submit(payment_data, transaction_id)
        pp(transaction_id)
        pp(payment_data)
        # TODO: validate payment data again?

        # client = Konfipay::Client.new

        # TODO: Add possibility to split into batches right away?

        # Comments here are from sepa_king docs: https://github.com/salesking/sepa_king
        builder = SEPA::CreditTransfer.new(
          # Name of the initiating party and debtor, in German: "Auftraggeber"
          # String, max. 70 char
          name: payment_data["debtor"]["name"],
          # OPTIONAL: Business Identifier Code (SWIFT-Code) of the debtor
          # String, 8 or 11 char
          bic:  payment_data["debtor"]["bic"],
          # International Bank Account Number of the debtor
          # String, max. 34 chars
          iban: payment_data["debtor"]["iban"]
        )
        payment_data["creditors"].each do |creditor_data|
          builder.add_transaction(
            # Name of the creditor, in German: "Zahlungsempfänger"
            # String, max. 70 char
            name:                   creditor_data["name"],
            # OPTIONAL: Business Identifier Code (SWIFT-Code) of the creditor's account
            # String, 8 or 11 char
            bic:                    creditor_data["bic"],
            # International Bank Account Number of the creditor's account
            # String, max. 34 chars
            iban:                   creditor_data["iban"],
            # Amount
            # Number with two decimal digit
            amount:                 (Float(creditor_data["amount_in_cents"]) / 100),
            # OPTIONAL: Currency, EUR by default (ISO 4217 standard)
            # String, 3 char
            currency:               creditor_data["currency"],
            # OPTIONAL: End-To-End-Identification, will be submitted to the creditor
            # String, max. 35 char
            reference:              creditor_data["end_to_end_reference"],
            # OPTIONAL: Unstructured remittance information, in German "Verwendungszweck"
            # String, max. 140 char
            remittance_information: creditor_data["remittance_information"],
            # OPTIONAL: Requested execution date, in German "Ausführungstermin"
            # Date
            requested_date: Date.parse(creditor_data["execute_on"]),
            # OPTIONAL: Enables or disables batch booking, in German "Sammelbuchung / Einzelbuchung"
            # True or False
            batch_booking: true,
            # OPTIONAL: Urgent Payment
            # One of these strings:
            #   'SEPA' ("SEPA-Zahlung")
            #   'URGP' ("Taggleiche Eilüberweisung")
            service_level: 'SEPA'
          )
        end

        xml = builder.to_xml("pain.001.003.03")
        puts xml
        binding.pry

        # TODO: check data
        ## pp data
        # maybe split up in sub-tasks if there are very many transfers
        # make PAIN xml in memory
        # upload to konfipay
        # parse/check result

        {
          'r_id' => 'aaaaaaaaaaaa'
        }
      end
    end
  end
end
