# Check that StackStorm packages can be uninstalled without errors
describe 'st2 packages uninstall test' do
  describe command("$BASEDIR/scripts/remove_os_packages.sh #{spec[:package_list]}") do
      its(:exit_status) { is_expected.to eq 0 }
  end
end
