# OCI Images for Cyrus IMAP

This repo contains a Dockerfile for building a container that has all the
required libraries for building and testing Cyrus IMAP.  It is meant for use in
Cyrus IMAP's automated test runs, and for testing changes while developing
Cyrus.

There are two ways to acquire the OCI images.

## Build locally from a Dockerfile

Debian is the preferred platform for Cyrus IMAP, so these instructions will be
specific to Debian distributions.  While we'd like to support multiple
platforms in the future, we do not currently do so.

The `Dockerfile` is in the `Debian` directory. To build the Debian
based OCI image, run the following commands from the current
directory:

```
$ cd Debian
$ docker build -t <image-name> .
```

where `<image-name>` could be anything you like. Because the current OCI
image is based on [Debian
"bookworm"](https://www.debian.org/releases/bookworm/), we would typically run
it as:

```
$ docker build -t cyrus-bookworm .
```

..and let Docker do its thing.

## Fetch latest images from the GitHub Container Repository

```
$ docker pull ghcr.io/cyrusimap/cyrus-docker:trixie
```

The `bookworm` and `trixie` tags are rebuilt nightly from `master`, and the
`dev` branch publishes `bookworm-dev` and `trixie-dev`.

### Alternative images

Sometimes you want the same image with a different cyruslibs, say to test
Cyrus against the libraries a particular release ships, or with an older
JMAP-TestSuite, because the current one has moved past what an older Cyrus
can pass.  Run the "Create and publish an OCI image" workflow by hand and fill
in:

* **debian**: `bookworm`, `trixie`, or `all`
* **cyruslibs**: the cyruslibs branch or tag to build, e.g. `cyruslibs-fastmail-v68`
* **jmap-testsuite**: the JMAP-TestSuite branch, tag, or commit to install
* **suffix**: a short name for the result, e.g. `libs68`

That publishes `trixie-libs68` (and `bookworm-libs68`, with `all`).  Run from
a branch other than `master`, the branch name goes between, as in
`trixie-dev-libs68`.  The suffix is yours to choose, so check the
`org.cyrusimap.cyrus-docker.cyruslibs` and `.jmap-testsuite` labels if you
need to know what an image was really built from.

These images are not rebuilt nightly.  They stay as built until someone runs
the workflow again with the same suffix, or deletes them.

Turn off **push** to check that an image builds without publishing anything.


## Running the Docker instance

To run the built container:

```
$ docker run -it ghcr.io/cyrusimap/cyrus-docker:trixie
```

(Or provide whatever name you use when building the image yourself.)

You'll be dropped into an interactive shell with some help about how to go
about cloning and testing Cyrus IMAP.  You can also look at the included `dar`
tool (`./bin/dar`)) for how to use this container while working on your
own branch of Cyrus IMAP.
