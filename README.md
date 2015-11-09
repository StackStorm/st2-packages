[![Build Status](http://drone.noops.tk/api/badge/github.com/dennybaa/st2-packages/status.svg?branch=master)](http://drone.noops.tk/github.com/dennybaa/st2-packages)

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

## License and Authors

* Author:: StackStorm (st2-dev) (<info@stackstorm.com>)
* Author:: Denis Baryshev (<dennybaa@gmail.com>)
