require 'spec_helper'

describe 'st2 cli version checks' do
  describe command(spec[:st2_client_version]) do
    its(:exit_status) { is_expected.to eq 0 }
    puts described_class.stdout
  end

  if spec[:mistral_enabled]
    describe command(spec[:mistral_client_version]) do
      its(:exit_status) { is_expected.to eq 0 }
      puts described_class.stdout
    end
  end
end
