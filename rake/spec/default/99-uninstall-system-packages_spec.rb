# Check that StackStorm packages can be uninstalled without errors
describe 'st2 packages uninstall test' do
  spec[:package_list].each do |pkg_name|
    if os[:family] == 'redhat'
      describe command("sudo yum -y remove #{pkg_name}") do
        its(:exit_status) { is_expected.to eq 0 }
      end
    elsif os[:family] == 'ubuntu'
      describe command("sudo apt-get remove -y #{pkg_name}") do
        its(:exit_status) { is_expected.to eq 0 }
      end
    end
  end
end
