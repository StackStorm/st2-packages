
# build buildenv container
Buildenv should be pushed to dockerhub, so there's no need to build it.

```
docker build -f buildenv/Dockerfile.debian -t st2packages_buildenv .
```


# build packaging container
```
docker build --no-cache -f package/Dockerfile.debian -t st2packages_debian .
```

# run build
```
docker run -it --rm -v $(pwd)/sources:/sources st2packages_debian
```
