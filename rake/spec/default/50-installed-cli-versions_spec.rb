require 'spec_helper'

describe 'st2 cli version checks' do
  describe command("st2 --version") do
    its(:exit_status) { is_expected.to eq 0 }
    its(:stdout) { should match /on Python 3.6/ }
    # show version number in Rspec output
    after(:all) do
      puts puts "    " + described_class.stderr
    end
  end

end
