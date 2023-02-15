# Searchd container image based on Red Hat Linux

[![image-build](https://github.com/3scale/searchd/actions/workflows/container-image-buildah.yml/badge.svg)](https://github.com/3scale/searchd/actions/workflows/container-image-buildah.yml)
[![lint](https://github.com/3scale/searchd/actions/workflows/lint.yml/badge.svg)](https://github.com/3scale/searchd/actions/workflows/lint.yml)

## Build image

```
podman build --squash -t 3scale-searchd .
```

Optionally supply `--build-arg PORTA_IMAGE=value` to use something different than the default `quay.io/3scale/porta:nightly`.

## Lint Containerfile

```
hadolint Containerfile
```

## Run locally

To simulate OpenShift environment run it as non-root like this:
```
podman run --rm -ti -u 14:0 -p 9306:9306 quay.io/3scale/searchd:latest
```

Then you can connect with `mysql` client:
```
mysql -h 127.0.0.1 -P 9306
SELECT * FROM account limit 1;
```

## Issues

Please report any issues to https://issues.redhat.com/browse/THREESCALE using component `system`.
