# Check that StackStorm packages can be uninstalled without errors
describe 'st2 packages uninstall test' do
  spec[:package_list].each do |pkg_name|
    if os[:family] == 'redhat'
      # Verify package is installed
      describe command("rpm -q #{pkg_name}") do
        its(:exit_status) { is_expected.to eq 0 }
      end

      describe command("sudo yum -y remove #{pkg_name}") do
        its(:exit_status) { is_expected.to eq 0 }
      end

      # Verify package has been uninstalled successfully
      describe command("rpm -q #{pkg_name}") do
        its(:exit_status) { is_expected.to eq 1 }
      end
    elsif os[:family] == 'ubuntu'
      # Verify package is installed
      describe command("dpkg -l #{pkg_name}") do
        its(:exit_status) { is_expected.to eq 0 }
      end

      describe command("sudo apt-get remove -y --purge #{pkg_name}") do
        its(:exit_status) { is_expected.to eq 0 }
      end

      # Verify package has been uninstalled successfully
      describe command("dpkg -l #{pkg_name}") do
        its(:exit_status) { is_expected.to eq 1 }
      end
    end
  end
end
