[![Build Status](http://drone.vos.io/api/badge/github.com/dennybaa/st2-packages/status.svg?branch=master)](http://drone.vos.io/github.com/dennybaa/st2-packages)

# Stackstorm CI environment for building OS packages

This whole process of continuous integration bases on docker to provide an easy an configurable way to build, install and test Stackstorm OS packages.

Stackstorm OS packages include a complete pre-built and independent python virtual environments containing a single st2 component. This is that what makes such independent and it can be easily installed/removed or upgraded separately from other stackstorm OS packages.

CI process consist of three phases:

 - **Package build phase**. Packages are build for a specific platform family.
 - **Package installation phase**. Built packages are transferred on to a remote test node.
 - **Integration tests phase**. Integration suite is run on a special worker node, but checks happen on a remote test node.

The second and the third phases have multi-node support which makes it possible to build once packages say it for debian system and then repeat phases *2, 3* on different nodes such can be ubuntu trusty, debian jessie, debian wheezy.

Suite can be run operate locally using docker-compose or can be enrolled in a drone environment for real CI operation.

## Metadata and configuration

We can provide several options to configure our suite, let's take a look at docker-compose yaml data:

```yaml
ubuntu:
  image: quay.io/dennybaa/droneruby
  working_dir: /root/workdir
  entrypoint: ["/bin/bash", "/root/workdir/.drone/build.sh"]
  environment:
    # Full list of st2 packages configures the default build
    - COMPOSE=1
    - ST2_PACKAGES=st2common st2actions st2api st2auth st2client st2reactor
    - ST2_GITURL=https://github.com/dennybaa/st2.git
    - ST2_GITREV=setuptools_packaging_improvements
    - BUILDHOST=buildenvdeb
    - TESTHOSTS=trusty
    - DEBUG=1
  links:
    - buildenvdeb
    - rabbitmq
    - mongodb
    - trusty
  volumes:
    - .:/root/workdir
    - /tmp/st2-packages:/root/packages
```

This is the configuration of worker machine which is a ruby one and it's able to run rspec tests, integration tests are base on [serverspec](http://serverspec.org) library.

Let's describe a few important variables:

 - **ST2_PACKAGES** - specifies a full list of st2 components which defines what components will be built.
 - **ST2_GITURL** - specifies an URL of upstream stackstorm sources.
 - **ST2_GITREV** - specifies a revision or branch which will be checked out.
 - **BUILDHOST** - specifies a node where packages build process happens.
 - **TESTHOSTS** - specifies a list of nodes which the integration tests will be performed upon.

## Running suite with docker compose

Issue the whole suite will be run, after it finishes you can find packages in your `/tmp/st2-packages` directory.
```
docker-compose run --rm ubuntu
```

## License and Authors

* Author:: StackStorm (st2-dev) (<info@stackstorm.com>)
* Author:: Denis Baryshev (<dennybaa@gmail.com>)
