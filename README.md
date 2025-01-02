# Docker Images for Cyrus IMAP

This repo contains a Dockerfile for building a container that has all the
required libraries for building and testing Cyrus IMAP.  It is meant for use in
Cyrus IMAP's automated test runs, and for testing changes while developing
Cyrus.

There are two ways to acquire the Docker images.

## Build locally from a Dockerfile

Debian is the preferred platform for Cyrus IMAP, so these instructions will be
specific to Debian distributions.  While we'd like to support multiple
platforms in the future, we do not currently do so.

The `Dockerfile` is in the `Debian` directory. To build the Debian
based Docker image, run the following commands from the current
directory:

```
$ cd Debian
$ docker build -t <image-name> .
```

where `<image-name>` could be anything you like. Because the current Docker
image is based on [Debian
"bookworm"](https://www.debian.org/releases/bookworm/), we would typically run
it as:

```
$ docker build -t cyrus-bookworm .
```

..and let Docker do its thing.

## Fetch latest images from the GitHub Container Repository

```
$ docker pull ghcr.io/cyrusimap/cyrus-docker:nightly
```


## Running the Docker instance

To run the built container:

```
$ docker run -it ghcr.io/cyrusimap/cyrus-docker:nightly
```

(Or provide whatever name you use when building the image yourself.)

You'll be dropped into an interactive shell with some help about how to go
about cloning and testing Cyrus IMAP.  You can also look at the included `dar`
tool (`./bin/dar)) for how to use this container while working on your
own branch of Cyrus IMAP.
