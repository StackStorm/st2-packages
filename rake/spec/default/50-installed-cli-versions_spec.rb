require 'spec_helper'

describe 'st2 cli version checks' do
  describe command("st2 --version") do
    puts described_class.stdout
    puts described_class.stderr
    its(:exit_status) { is_expected.to eq 0 }
  end

  if spec[:mistral_enabled]
    describe command("mistral --version") do
      its(:exit_status) { is_expected.to eq 0 }
      puts described_class.stdout
    end
  end
end
