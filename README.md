[![Build Status](http://drone.vos.io/api/badge/github.com/dennybaa/st2-packages/status.svg?branch=master)](http://drone.vos.io/github.com/dennybaa/st2-packages)

# Building debian packages

## Install docker compose

Make sure you've got version >= 1.3.0rc3
```
pip install docker-compose
```

## Build containers

Build packaging container with the following command:
```
docker-compose build

# Or if you want to rebuild packaging containers invoke
docker-compose build --no-cache
```

## Build packages

On build docker mounts host /tmp directory where built debian packages will be written. Invocation examples:
```
# Build all world
docker-compose up -d buildenvdeb && \
docker-compose run --rm ubuntu

# Build specific st2 packages.
# First command is required as it rebuilds buildenvdeb container
docker-compose up -d buildenvdeb && \
docker-compose run --rm ubuntu st2actions st2api

# Finally you may want to clean up buildenvdeb container
docker-compose stop && docker-compose rm -f
```

## Trying if IT's real:)
I suggest to try it out first. So make sure you've build contaners
```
docker-compose build
```

Futher the creation of st2common, st2api package will be explained, but first we need to issue the build command:

```
docker-compose run --rm debian st2common st2api 
```

For development/debug purposes the package container ramains working after the build finishes. So you can login to it and try newly built packages.


```
docker exec -it st2packages_debian_run_1 /bin/bash
# The following commands will be issued inside the debian container
dpkg -i /out/st2common_0.12dev_all.deb
dpkg -i /out/st2api_0.12dev_amd64.deb

# don't forget to look inside sample light deploy
/code/tools/st2-light-deploy.sh
/etc/init.d/mongodb start
/etc/init.d/rabbitmq-server start
/etc/init.d/st2api start

# And finally
/etc/init.d/st2api status
```

Basically the installation was drastically simplified with introduction of "normal" packages. Just have a look inside https://github.com/dennybaa/st2-packages/blob/master/sources/tools/st2-light-deploy.sh, I guess it's self-explanatory.
