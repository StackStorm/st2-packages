[![Circle CI](https://circleci.com/gh/dennybaa/st2-packages.svg?style=svg)](https://circleci.com/gh/dennybaa/st2-packages)

# Stackstorm packages build environment

## Highlights

 - **Docker based**. Leveraging docker it's possible to deliver packages for any OS distro in fast and reliable way.
 - [Rake](https://github.com/ruby/rake) + [sshkit](https://github.com/capistrano/sshkit) based execution enables easy configuration via **simple DSL** and brings **parallel task processing** out of the box.
 - **Test-driven workflow**. Artifacts built are not only available for any enabled OS distro but at the same time tested on a bunch of platforms, providing feedback such as can be installed, services can start up, operations can be executed etc.

## Overview

Packages build environment is a *multi-container docker* application defined and managed with [docker-compose](https://github.com/docker/compose). It consists of four types of containers:

 - **Packaging runner** (https://quay.io/stackstorm/packagingrunner) - the main entry point, package build and test processing controller container.
 - **Build environment** (https://quay.io/stackstorm/packagingenv) - container where actual artifacts build takes place. It's used to bring up the build environment specific for OS distro. This means that different containers are available such as *packagingenv:centos6*, *packagingenv:wheezy* correspondingly for CentOS 6 and Debian Wheezy.
 - **Test runner** (https://quay.io/dennybaa/droneunit) - containers where built artifacts are tested, i.e. *artifacts are installed, configuration is written and tests are performed*.
 - **Services** - these are different containers required for testing such as *rabbitmq, mongodb and postgress*

Packages build environment compose application brings all-sufficient pipeline to deliver ready to use packages.

# Usage

It's very simple to invoke the whole build-test pipeline. First just make sure that [docker-compose.yml](docker-compose.yml) has your distro specification, after that issue the following commands:

```shell
# First clean out previous build containers (it's optional)
docker-compose -f compose.yml -f docker-compose.yml kill
docker-compose -f compose.yml -f docker-compose.yml rm -f

# We want to build packages for debian wheezy
docker-compose -f compose.yml -f docker-compose.yml run wheezy
```

Execution takes about *6 to 10 minutes* to build around 10 packages it depends on computing power of your CPU. When build and tests are finished, you can find all of StackStorm packages in your host local directory `/tmp/st2-packages`:

```shell
ls -l1 | grep ".deb$"
-rw-r--r-- 1 root root 26757508 Nov 22 22:51 mistral_1.1.0-1~st2_amd64.deb
-rw-r--r-- 1 root root 20449448 Nov 22 22:50 st2actions_1.2dev-1_amd64.deb
-rw-r--r-- 1 root root 17847628 Nov 22 22:50 st2api_1.2dev-1_amd64.deb
-rw-r--r-- 1 root root 18581330 Nov 22 22:50 st2auth_1.2dev-1_amd64.deb
-rw-r--r-- 1 root root 23808024 Nov 22 22:51 st2bundle_1.2dev-1_amd64.deb
-rw-r--r-- 1 root root 18234622 Nov 22 22:50 st2client_1.2dev-1_amd64.deb
-rw-r--r-- 1 root root 20127732 Nov 22 22:48 st2common_1.2dev-1_amd64.deb
-rw-r--r-- 1 root root 19107338 Nov 22 22:50 st2debug_1.2dev-1_amd64.deb
-rw-r--r-- 1 root root 17962818 Nov 22 22:50 st2exporter_1.2dev-1_amd64.deb
-rw-r--r-- 1 root root 18273728 Nov 22 22:50 st2reactor_1.2dev-1_amd64.deb
```

# License and Authors

* Author:: StackStorm (st2-dev) (<info@stackstorm.com>)
* Author:: Denis Baryshev (<dennybaa@gmail.com>)
