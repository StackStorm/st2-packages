require 'spec_helper'

# Check that st2mistral can run internal actions successfully
describe 'st2mistral actions integrity checks' do
  if spec[:mistral_enabled]
    describe command(%(mistral run-action std.echo '{"output": "It works!"}')) do
      its(:exit_status) { is_expected.to eq 0 }
      its(:stdout) { should include '{"result": "It works!"}' }
    end
  end
end
