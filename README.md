# Docker Images for Cyrus IMAP

These Docker images contain all the required libraries for setting up and
running an instance of Cyrus IMAP.

There are 2 ways to acquire the Docker images.

## Build locally from a Dockerfile

Debian is the preferred platform for CyrusIMAP, so these instructions will be
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

## Fetch latest images from hub.docker.com

```
$ docker pull cyrusimapdocker/cyrus-bookworm
```


## Running the Docker instance

To run the built container:


```
$ docker run -it --sysctl net.ipv6.conf.all.disable_ipv6=0 cyrus-bookworm
```

If the image has been fetched from hub.docker.com, run it like so:

```
$ docker run -it --sysctl net.ipv6.conf.all.disable_ipv6=0 cyrusimapdocker/cyrus-bookworm
```
