require 'serverspec'

set :backend, :exec

shared_examples 'owner_has_rwx' do |user|
  it { is_expected.to be_owned_by user }
  it { is_expected.to be_readable.by 'owner' }
  it { is_expected.to be_writable.by 'owner' }
  it { is_expected.to be_executable.by 'owner' }
end
