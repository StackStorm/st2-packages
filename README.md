
# build buildenv container
Buildenv should be pushed to dockerhub, so there's no need to build it.

```
docker build -f buildenv/Dockerfile.debian -t st2buildenv-debian .
```


# build packaging container
```
docker build --no-cache -f package/Dockerfile.debian -t st2package-debian .
```

# run build
```
docker run -it --rm -v $(pwd)/sources:/sources st2package-debian
```
