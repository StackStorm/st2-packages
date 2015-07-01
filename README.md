# Building debian packages

1. **Install docker compose**

  Make sure you've got version >= 1.3.0rc3
  ```
  pip install docker-compose
  ```

1. **Build containers**

  For the first build run:
  ```
  docker-compose build
  ```
  if you want to rebuild packaging container run:
  ```
  docker-compose build --no-cache debian
  ```

1. **Build packages**
  On build docker mounts host /tmp directory where built debian packages
  will be written. To build debian packages invoke 
  ```
  # Build all st2 packages
  docker-compose run debian

  # Build specific st2 packages
  docker-compose run debian st2actions st2api
  ```

1. **Trying if IT's real:)**
  I suggest to try it out first. So make sure you've build contaners
  ```
  docker-compose build
  ```
  Next make sure you've removed all running package container:
  ```
  docker rm -f st2packages_debian_run_1
  ```
  After this build `st2common` and `st2api`, the whole approach will be shown bellow for these two packages. No issue the build command:
  ```
  docker-compose run debian st2common st2api
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
