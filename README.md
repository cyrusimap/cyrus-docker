# Docker Images for Cyrus IMAP

These Docker images contain all the required libraries for setting up and running an instance of Cyrus IMAPd.

There are 2 ways to acquire the Docker images.

## Build locally from a Dockerfile

Debian is the preferred platform for CyrusIMAPd to run. So these
instructions will be specific to Debian distributions. While there is
a plan to support multiple platforms in the future, we do not
currently do so.

The `Dockerfile` is in the `Debian` directory. To build the Debian
based docker image, run the following commands from the current
directory:

```
$ cd Debian
$ docker build -t <image-name> .
```

where `<image-name>` could be anything you like. Because the current
docker image is based of buster, we would typically run it as:

```
$ docker build -t cyrus-buster .
```

..and let docker do its thing.

## Fetch latest images from hub.docker.com

```
$ docker pull cyrusimapdocker/cyrus-buster
```


## Running the docker instance

To run the built container:


```
$ docker run -it cyrus-buster /bin/sh
```

If the image has been fetched from hub.docker.com, run it like so:

```
$ docker run -it cyrusimapdocker/cyrus-buster /bin/sh

```

NOTE: Please note that this README assumes that the image being built
is `cyrus-buster` and based on [Debian
buster](https://www.debian.org/releases/buster/). Please replace with
the appopriate relase to reflect the changes in the `Dockerfile`.
