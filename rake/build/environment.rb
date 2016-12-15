#!/usr/bin/env ruby
require 'hashie'
require 'resolv'

## Build pipeline environment configuration file
#  ---------------------------------------------

# St2 components which are part of the bundle package
ST2_COMPONENTS = %w(
  st2api st2stream st2actions st2common
  st2auth st2client st2exporter
  st2reactor
  st2debug)

# Default list of packages to build
BUILDLIST = 'st2 st2mistral'

##  Helper procs
convert_to_ipaddr = ->(v) {(v !~ Resolv::AddressRegex) ? Resolv.getaddress(v) : v}
convert_to_int = ->(v) {v.to_i}
convert_to_array = ->(a) do
  if a.is_a? Array
    a
  else
    list = a.to_s.split(' ')
    list.empty? ? [] : list
  end
end

pipeopts do
  ssh_options({
    keys: %w(/root/.ssh/busybee),
    auth_methods: %w(publickey)
  })

  ## Attributes
  # buildnode - hostname or address of remote build node (where build is run)
  # testnode  - hostname or address of remote test node (where tests are run)
  # package_list - a space separated list of packages to built, overrides BUILDLIST
  #
  env     :buildnode
  env     :testnode
  env     :packages,     BUILDLIST, from: 'ST2_PACKAGES', proc: convert_to_array
  env     :package_list, BUILDLIST, from: 'ST2_PACKAGES'

  ## Envpass attributes
  #     are fetch from environment variables, however they are also made
  #     visible to remote nodes.
  #
  # basedir - base directory (intermediate files are copied there)
  # artifact_directory - directory on the main node where artificats are copied
  # wheeldir - direcotory where wheels are prefetched (cache directory)
  # st2_python - if variable is set that means that our version of python is used
  envpass :basedir,  '/root'
  envpass :debug_level, 1, proc: convert_to_int
  envpass :artifact_dir, '/root/build'
  envpass :wheeldir, '/tmp/wheelhouse'
  envpass :st2_python, 0, proc: convert_to_int

  # Default hostnames of dependat services (the value can take an address also)
  envpass :rabbitmqhost, 'rabbitmq', proc: convert_to_ipaddr
  envpass :mongodbhost,  'mongodb',  proc: convert_to_ipaddr
  envpass :postgreshost, 'postgres', proc: convert_to_ipaddr

  # upload_sources - a list of directories which should be propogated
  #                  to remote nodes.
  upload_sources 'packages', 'scripts', 'rpmspec'
end

pipeopts 'st2' do
  env :components, ST2_COMPONENTS, proc: convert_to_array
  checkout true
  envpass :giturl,   'https://github.com/StackStorm/st2', from: 'ST2_GITURL'
  envpass :gitrev,   'v2.1',                            from: 'ST2_GITREV'
  envpass :gitdir,    make_tmpname('st2-'),               from: 'ST2_GITDIR'
  envpass :st2pkg_version
  envpass :st2pkg_release, 1
  envpass :st2_circle_url
end

pipeopts 'st2mistral' do
  checkout true
  envpass :giturl,  'https://github.com/StackStorm/mistral', from: 'ST2MISTRAL_GITURL'
  envpass :gitrev,  'st2-2.1.1',                             from: 'ST2MISTRAL_GITREV'
  envpass :gitdir,  make_tmpname('mistral-')
  envpass :mistral_version, '2.1.1'
  envpass :mistral_release, 1
end
