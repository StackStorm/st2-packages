require 'spec_helper'

describe 'st2 cli version checks' do
  describe command("st2 --version") do
    its(:exit_status) { is_expected.to eq 0 }
    # TODO: Show version number in Rspec output
    puts described_class.stdout
  end

  if spec[:mistral_enabled]
    describe command("mistral --version") do
      its(:exit_status) { is_expected.to eq 0 }
      # TODO: Show version number in Rspec output
      puts described_class.stdout
    end
  end
end
