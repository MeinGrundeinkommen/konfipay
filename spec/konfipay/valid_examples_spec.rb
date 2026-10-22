# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable-next RSpec/DescribeClass
RSpec.describe 'example file' do
  # By necessity, our example files for specs are hand-edited
  # (we can't use real files obviously) so let's make sure the files
  # themselves are correct by validating against their XSD schemas.
  #
  # The schema files have been downloaded from here:
  #
  # https://www.ebics.de/de/datenformate/ergaenzende-dokumente
  #
  # in september 2026.
  #
  # CAMT schema was in ISO-Schemacamt05x_Version_2019.zip
  # PAIN schemas were in DK-TVS_SEPA_GBIC_5zzglISO_Originale.zip
  #
  # Note that the sepa_rator gem automatically validates the generated
  # actual SEPA PAIN XML which gets sent to Konfipay, so no need to
  # double-validate that.
  Dir.glob('spec/examples/*.xml').each do |xml_path|
    describe xml_path do
      # rubocop:disable-next RSpec/LeakyLocalVariable
      schema_path = "spec/schemas/#{File.basename(xml_path).split('-').first}.xsd"
      let(:xml) { Nokogiri::XML::Document.parse(File.read(xml_path)) }
      let(:schema_path) { schema_path }
      let(:schema) { Nokogiri::XML::Schema.new(File.read(schema_path)) }

      describe "with schema #{schema_path}" do
        it 'has no errors' do
          expect(schema.validate(xml)).to eq([])
        end
      end
    end
  end
end
