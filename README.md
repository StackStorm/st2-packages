# Stackstorm packages build environment

[![Circle CI Build Status](https://circleci.com/gh/StackStorm/st2-packages/tree/master.svg?style=shield)](https://circleci.com/gh/StackStorm/st2-packages)
[![Go to Docker Hub](https://img.shields.io/badge/Docker%20Hub-%E2%86%92-blue.svg)](https://hub.docker.com/r/stackstorm/)
[![Download deb/rpm](https://img.shields.io/badge/Download-deb/rpm-blue.svg)](https://packagecloud.io/StackStorm/)

## Highlights

 - **Docker based**. Leveraging docker it's possible to deliver packages for any OS distro in a fast and reliable way.
 - [Rake](https://github.com/ruby/rake) + [sshkit](https://github.com/capistrano/sshkit)-based execution enables easy configuration via **simple DSL** and brings **parallel task processing** out of the box.
 - **Test-driven workflow**. Artifacts built are not only available for any enabled OS distro but at the same time tested on a bunch of platforms, providing feedback such as can be installed, services can start up, operations can be executed etc.

## Overview

Packages build environment is a *multi-container docker* application defined and managed with [docker-compose](https://github.com/docker/compose). It consists of four types of containers:

 - **Packaging runner** (https://quay.io/stackstorm/packagingrunner) - the main entry point, package build and test processing controller container.
 - **Packaging build** (https://hub.docker.com/r/stackstorm/packagingbuild/) - container where actual `.deb`/`.rpm` artifacts build takes place. It's used to bring up the build environment specific for OS distro. This means that different containers are available such as *packagingbuild:rocky8*, *packagingbuild:focal* correspondingly for RockyLinux 8 and Ubuntu Focal.
 - **Packaging test** (https://hub.docker.com/r/stackstorm/packagingtest/) - containers where built artifacts are tested, i.e. *artifacts are installed, configuration is written and tests are performed*.
 - **Services** - these are different containers required for testing such as *rabbitmq and mongodb*

`Dockerfiles` sources are available at [StackStorm/st2-dockerfiles](https://github.com/stackstorm/st2-dockerfiles).

The Packages build environment compose application brings a self-sufficient pipeline to deliver ready to use packages.

# Usage

It's very simple to invoke the whole build-test pipeline. First just make sure that [docker-compose.yml](docker-compose.yml) has your distro specification, after that issue the following commands:

```shell
# (Optional) First clean out previous build containers
docker-compose kill
docker-compose rm -f

# To build packages for ubuntu focal (--rm will wipe packaging runner container. All others will remain active).
docker-compose run --rm focal
```

Execution takes a while, so grab a cup of tea or coffee and wait until it finishes. When build and test processes succeed, you'll find the StackStorm packages in `/tmp/st2-packages` on your host machine:

```shell
ls -l1 | grep ".deb$"
-rw-r--r-- 1 root root 30872652 Feb  9 18:32 st2_1.4dev-1_amd64.deb
```

## Manual testing inside the docker environment

After the build and test stages are finished all docker containers remain active, so you are welcome to do more in-depth testing if desired. To do so simply run:

```
docker ps
# Find the required testing container
# In our case it will be st2packages_focaltest_1

# Simply exec to docker
docker exec -it st2packages_focaltest_1 bash
```

Once done, you are inside the testing environment where all services are up and running. Don't forget to do (after exec):

```
export TERM=xterm
```
At this point you can do any manual testing which is required.

# Vagrant based build and test

In order to build, package, install and test ST2 in an isolated Vagrant VM, run the following:

```
vagrant up $TARGET
```

Where `$TARGET` is one of `focal`, or `el8`. If you are using `el8`, comment
out the `vm_config.vm.provision :docker` line in the Vagrantfile. There is logic in `setup-vagrant.sh`
to install docker in `el8`.

The following steps are run while provisioning the Vagrant VM:

1. Install `docker` and `docker-compose`.
2. Run `docker-compose run --rm $TARGET` to build, test and package ST2 as described in prior
   sections.
3. Install the packages built in step 2, unless the host `$ST2_INSTALL` environment variable is set to
   a value other than `yes`.
4. Execute the `st2-self-check` script, unless the host `$ST2_VERIFY` environment variable is set to
   a value other than `yes`.

As currently implemented, it is not possible to bypass steps 1 and 2. In the future, we may want to
consider allowing the host to provide existing ST2 packages, and install/self-check those in the
Vagrant VM.

To specify the ST2 source URL and REV (i.e., branch), use `ST2_GITURL` and `ST2_GITREV` environment
variables on the host prior to provisioning the VM. 

Prior to running `st2-self-check`, the required auth token is generated using `st2 auth`.  If necessary,
you can change the default username and password passed to `st2 auth`.  To do this, set the `ST2USER`
and `ST2PASSWORD` environment variables on the host prior to provisioning the VM. The default values
are `st2admin` and `Ch@ngeMe` respectively.

# Installation
Current community packages are hosted on https://packagecloud.io/StackStorm. For detailed instructions how install st2 and perform basic configuration follow these instructions:
- [Ubuntu/Debian](https://docs.stackstorm.com/install/deb.html)
- [RHEL8/RockyLinux8](https://docs.stackstorm.com/install/rhel8.html)

## Adding Support For a New Distribution

If you are adding support for a new distribution for which ``packagingbuild`` and ``packagingtest``
images are not yet published to Docker Hub and you want to test the build pipeline locally, you
need to update ``docker-compose.yml`` file to use locally built Docker images.

For example:

```yaml
...

focal:
  ...
  image: quay.io/stackstorm/packagingrunner
  ...
...

focalbuild:
  ...
  image: focalbuild
  ...

...

focaltest:
  ...
  image: focaltest
  ...
```

NOTE: Main ``distro`` definition (e.g. ``focal``, etc.) needs to use packaging runner image.

As you can see, ``image`` attribute references local image tagged ``focalbuild`` instead of a
remote image (e.g. ``stackstorm/packagingbuild:focal`` or similar).

Before that will work, you of course also need to build those images locally.

For example:

```bash
cd ~/st2packaging-dockerfiles/packagingbuild/focal
docker build -t focalbuild .

cd ~/st2packaging-dockerfiles/packagingtest/focal/systemd
docker build -t focaltest .
```

# License and Authors

* Author:: StackStorm (st2-dev) (<info@stackstorm.com>)
* Author:: Denis Baryshev (<dennybaa@gmail.com>)
