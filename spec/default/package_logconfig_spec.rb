require 'spec_helper'

# Log config file checker example.
# It checks log config file existance and it checks that
# it directs logs into correct destination directory.
#
shared_examples 'has log config' do |opts|
  confdir = "/etc/#{opts[:package]}"
  logdir = ST2Specs[:log_dir]
  let(:content) { described_class.content }

  describe file(confdir) do
    it { is_expected.to be_directory }
  end

  logto = lambda do |filename|
    [
      %r{#{logdir}/#{filename}.log},
      %r{#{logdir}/#{filename}.audit.log}
    ]
  end

  # Perform matching log destinations based on provided match list
  if opts.keys.include? :match
    opts[:match].each do |hash|
      name, match_string = hash.first
      name = nil if name == :_default
      conf_filename = [name, 'conf'].compact.join('.')

      describe file("#{confdir}/logging.#{conf_filename}") do
        re_list = logto.call(match_string)

        it "should match #{re_list.map(&:inspect).join(', ')}" do
          re_list.each { |re| expect(content.match(re)).not_to be_nil }
        end
      end
    end

  # Perform default match
  else

    describe file("#{confdir}/logging.conf") do
      it do
        logto.call(opts[:package]).each do |re|
          expect(content).to match(re)
        end
      end
    end
  end
end

describe 'Package log config files' do
  it_behaves_like 'has log config', package: 'st2api'
  it_behaves_like 'has log config', package: 'st2auth'
  it_behaves_like 'has log config', package: 'st2actions',
                                    match: [
                                      { _default: 'actionrunner.{pid}' },
                                      { 'notifier' => 'st2notifier' },
                                      { 'resultstracker' => 'st2resultstracker' }
                                    ]
  it_behaves_like 'has log config', package: 'st2reactor',
                                    match: [
                                      { 'rulesengine' => 'st2rulesengine' },
                                      { 'sensorcontainer' => 'st2sensorcontainer' }
                                    ]
end
