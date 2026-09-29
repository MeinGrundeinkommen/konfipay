# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "example file" do
  Dir.glob('spec/examples/*.xml').each do |xml_path|
    let(:xml) { Nokogiri::XML::Document.parse(File.read(xml_path)) }
    describe xml_path do
      schema_path = "spec/schemas/#{File.basename(xml_path).split('-').first}.xsd"
      let(:schema_path) { schema_path }
      let(:schema) { Nokogiri::XML::Schema.new(File.read(schema_path)) }
      describe "with schema #{schema_path}" do
        it "has no errors" do
          puts schema.valid?(xml)
          expect(schema.validate(xml)).to eq([])
        end
      end
    end
  end
end
