require 'spec_helper'

describe 'logs configuration' do
  spec[:service_list].each do |service_name|
    # Get package name where service belongs to
    package_name = service_name
    found = spec[:package_has_services].find do |(_, list)|
      list.include? service_name
    end
    package_name = found.first if found

    # Set suffix if required
    if spec[:separate_log_config].include?(service_name)
      service_suffix = service_name.sub(/^st2/, '')
    end

    config_name = ['logging', service_suffix, 'conf'].compact.join('.')
    config_path = File.join([spec[:etc_dir], package_name, config_name])

    # list of log destination regex
    pattern = spec[:logdest_pattern][service_name] || service_name
    re_list = [
      /#{File.join(spec[:log_dir], pattern)}.log/,
      /#{File.join(spec[:log_dir], pattern)}.audit.log/
    ]

    # check logging consitency
    describe file(config_path) do
      let(:content) { described_class.content }

      it { is_expected.to be_file }
      it "should match #{re_list.map(&:inspect).join(', ')}" do
        re_list.each { |re| expect(content.match(re)).not_to be_nil }
      end
    end
  end
end
