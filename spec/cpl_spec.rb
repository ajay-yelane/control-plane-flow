# frozen_string_literal: true

require "spec_helper"

options_by_key_name = Command::Base.all_options_by_key_name
non_boolean_options_by_key_name = options_by_key_name
                                  .reject { |_, option| option[:params][:type] == :boolean }

describe Cpl do
  it "has a version number" do
    expect(Cpl::VERSION).not_to be_nil
  end

  non_boolean_options_by_key_name.each do |option_key_name, option|
    it "raises error if no value is provided for '#{option_key_name}' option" do
      result = run_cpl_command("test", option_key_name)

      expect(result[:status]).not_to eq(0)
      expect(result[:stderr]).to include("No value provided for option '#{option[:name]}'")
    end
  end
end
