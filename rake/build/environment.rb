#!/usr/bin/env ruby
require 'hashie'
require 'resolv'

## Defines options for the build pipeline.
#   NB! Should be ordered with st2common going first and
#   NB! st2 going after all st2 components.
#
DEFAULT_PACKAGES = %w(
  st2common st2api st2actions
  st2auth st2client st2exporter
  st2reactor st2debug st2
  st2mistral mistral
)

pipeopts do
  ssh_options({
    keys: %w(/root/.ssh/busybee),
    auth_methods: %w(publickey)
  })

  ## Load the following attributes from corresponding environment variables
  #

  env     :buildnode
  env     :testnode
  # package_lists specifies the list of packages to be built
  env     :package_list, from: 'ST2_PACKAGES'

  ## Load the following attributes from corresponding environment variables and
  ## also make the avialable as ENV on remote nodes (such as test and build).

  envpass :testmode, 'bundle' # bundle || component
  envpass :basedir,  '/root'
  envpass :debug_level, 1
  envpass :artifact_dir, '/root/build'    # make it temp??
  # Target directory for intermidiate files (on the remotes!)
  envpass :wheeldir, '/tmp/wheelhouse'

  # Services host variables
  envpass :rabbitmqhost, 'rabbitmq'
  envpass :mongodbhost, 'mongodb'
  envpass :postgreshost, 'postgres'

  ## Other attributes which set directly (not using env)

  # checkout sets what name contexts git repos should be checkd out.
  checkout :st2, :mistral, :st2mistral
  # specifies the list of directories to upload to remote nodes.
  upload_sources 'packages', 'scripts', 'rpmspec'
end

pipeopts 'st2python' do
  envpass :st2_python, 0
  envpass :st2_python_version, '2.7.10'
  envpass :st2_python_relase, 1
end

pipeopts 'st2' do
  # st2 packages are not standalone (ie. there are many $gitdir/st2*)
  standalone false
  checkout :st2
  envpass :giturl,   'https://github.com/StackStorm/st2', from: 'ST2_GITURL'
  envpass :gitrev,   'master',                            from: 'ST2_GITREV'
  envpass :gitdir,    make_tmpname('st2-'),               from: 'ST2_GITDIR'
  envpass :st2pkg_version
  envpass :st2pkg_release, 1
end

pipeopts 'mistral' do
  standalone true
  checkout :mistral
  envpass :giturl,  'https://github.com/StackStorm/mistral', from: 'MISTRAL_GITURL'
  envpass :gitrev,  'st2-1.3.0',                             from: 'MISTRAL_GITREV'
  envpass :gitdir,  make_tmpname('mistral-')
  envpass :mistral_version, '1.3.0'
  envpass :mistral_release, 1
end

pipeopts 'st2mistral' do
  standalone true
  checkout :st2mistral
  envpass :giturl,  'https://github.com/StackStorm/st2mistral', from: 'ST2MISTRAL_GITURL'
  envpass :gitrev,  'st2-1.3.0',                                from: 'ST2MISTRAL_GITREV'
  envpass :gitdir,  make_tmpname('st2mistral-')
  envpass :mistral_version, '1.3.0'
  envpass :mistral_release, 1
end


## --- Final pipeopts evaluation
python_enabled = pipeopts('st2python').st2_python.to_i

# packages and packages_to_test
list = pipeopts.package_list.to_s.split(' ')
packages = list.empty? ? DEFAULT_PACKAGES.dup : list
packages_to_test = packages.dup

# In components mode package st2 (bundle) is not installed.
if pipeopts.testmode == 'components'
  packages_to_test.delete('st2')
else
  # remove st2 components from the list
  packages_to_test.reject! {|p| p =~ /st2.+/ }
end

##
pipeopts do
  packages packages
  packages_to_test packages_to_test
  envpass :st2_python, python_enabled, reset: true

  # Force address resolution workaround (solves serverspec + netcat problems)
  [:rabbitmq, :mongodb, :postgres].each do |s|
    host = send(:"#{s}host")
    envpass(:"#{s}host", Resolv.getaddress(host), reset: true) if host !~ Resolv::AddressRegex
  end
end
