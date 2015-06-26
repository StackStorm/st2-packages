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
