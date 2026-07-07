# =============================================================================
# Cyrus IMAP development image (Debian)
#
# This Dockerfile builds "cyrus-docker", the image the Cyrus team uses for CI
# and for local development.  It is also meant to be *read*: the Cyrus developer
# documentation points here instead of maintaining a second list of build and
# test dependencies
#
# So, if you are setting up to build Cyrus somewhere other than this image --
# another distro, or bare metal -- this file is the authoritative answer to
# "what do I need?".  It's Debian-based, so you'll have to translate package
# names to your own system, but nothing required should be hidden elsewhere.
#
# The build proceeds in stages:
#
#   1. install Debian packages: the C build toolchain, the libraries Cyrus
#      links against, and the Perl modules Cassandane needs
#   2. create the "cyrus" user/group and minimal system config
#   3. fetch and build the external test tools we pin to known-good commits
#      (CalDAVTester, Dovecot, imaptest, JMAP-TestSuite)
#   4. build cyruslibs: libraries at versions newer than Debian ships
#   5. install "cyd", the in-container tooling, under /srv/bin
#
# Note that the build/test/coverage *steps* themselves live in cyd, not here.
# If you want to know exactly how Cyrus is configured, built, and tested, then
# read lib/Cyrus/Docker/Command/*.pm -- e.g. the reference ./configure
# invocation lives in Command/build.pm.
# =============================================================================

# If you change the default source image, update the README, which references
# the underlying Debian version.
ARG DEBIAN_VERSION=bookworm
FROM debian:$DEBIAN_VERSION
LABEL org.opencontainers.image.authors="Cyrus IMAP <docker@role.fastmailteam.com>"
LABEL org.cyrusimap.cyrus-docker.version="1.0"

RUN <<EOF
# install prerequisites via apt-get
#
# This list is deliberately a superset.  The unlabelled packages below are the
# C build toolchain, the libraries Cyrus links against, and the core Perl
# modules Cassandane needs to run.  The `# BEGIN ...` markers further down group
# packages added for specific purposes (extra Cassandane/Cyrus prereqs, the
# JMAP test suite, building the docs, and quality-of-life tools).
set -e
apt-get update
apt-get -y install build-essential
apt-get -y install --no-install-recommends \
    autoconf \
    automake \
    autotools-dev \
    bash-completion \
    bison \
    build-essential \
    check \
    clamav-freshclam \
    clang \
    cmake \
    comerr-dev \
    cpanminus \
    debhelper \
    doxygen \
    flex \
    g++ \
    gdb \
    git \
    gperf \
    graphviz \
    groff \
    texi2html \
    texinfo \
    heimdal-dev \
    help2man \
    libanyevent-perl \
    libauthen-scram-perl \
    libbsd-dev \
    libbsd-resource-perl \
    libclamav-dev \
    libclang-rt-dev \
    libcld2-dev \
    libclone-perl \
    libconfig-inifiles-perl \
    libcunit1-dev \
    libdatetime-perl \
    libdb-dev \
    libdbi-perl \
    libdigest-sha-perl \
    libencode-imaputf7-perl \
    libfile-chdir-perl \
    libfile-slurp-perl \
    libglib2.0-dev \
    libio-async-perl \
    libio-socket-inet6-perl \
    libio-stringy-perl \
    libjansson-dev \
    libjson-perl \
    libjson-xs-perl \
    libldap2-dev \
    libmagic-dev \
    libmilter-dev \
    default-libmysqlclient-dev \
    libnet-server-perl \
    libnews-nntpclient-perl \
    libnghttp2-dev \
    libpath-tiny-perl \
    libpam0g-dev \
    libplack-perl \
    libsasl2-dev \
    libsasl2-modules \
    libsnmp-dev \
    libsqlite3-dev \
    libssl-dev \
    libstring-crc32-perl \
    libtest-deep-perl \
    libtest-most-perl \
    libtest-tcp-perl \
    libtool \
    libunix-syslog-perl \
    liburi-perl \
    libxml-generator-perl \
    libxml-simple-perl \
    libxml-xpath-perl \
    libxml2-dev \
    libwrap0-dev \
    libwslay-dev \
    libwww-perl \
    libxapian-dev \
    libzephyr-dev \
    llvm \
    lsb-base \
    nano \
    net-tools \
    perl \
    pkg-config \
    po-debconf \
    python3-docutils \
    python3-myst-parser \
    python3-pygments \
    ripgrep \
    rsync \
    rsyslog \
    sudo \
    sphinx-common \
    tcl-dev \
    transfig \
    uuid-dev \
    vim \
    wamerican \
    wget \
    xutils-dev \
    xxd \
    zlib1g-dev \
    `# BEGIN Cyrus or Cassandane prereqs` \
    libclass-xsaccessor-perl \
    libdata-ical-perl \
    libdbd-sqlite3-perl \
    libdigest-crc-perl \
    libfile-libmagic-perl \
    libfile-mmagic-perl \
    libhttp-daemon-perl \
    libmath-int64-perl \
    libnet-ldap-perl \
    libnet-ldap-server-perl \
    libnet-ldap-server-test-perl \
    libterm-readline-gnu-perl \
    libtype-tiny-perl \
    `# BEGIN JMAP-TestSuite prereqs` \
    libcryptx-perl \
    libdata-guid-perl \
    libdata-printer-perl \
    libemail-mime-perl \
    libjson-maybexs-perl \
    libmoose-perl \
    libmoosex-role-parameterized-perl \
    libparse-recdescent-perl \
    libtest-deep-perl \
    libtest-routine-perl \
    libthrowable-perl \
    libwww-perl \
    `# BEGIN for building docs` \
    libpod-pom-view-restructured-perl \
    python3-breathe \
    python3-git \
    python3-sphinx \
    python3-sphinx-rtd-theme \
    rsync \
    valgrind \
    `# BEGIN for cyrus-docker or just quality of life` \
    less \
    libfile-pushd-perl \
    tini
EOF

RUN <<EOF
# set up users, groups, and config
#
# Cyrus expects to runs as the unprivileged "cyrus" user.  The important things
# are that it run as a non-root user in the groups "mail" and in "saslauth".
set -e
groupadd -r saslauth

# The "mail" group exists on stock Debian, we don't need to add it here.
# groupadd -r mail
useradd -c "Cyrus IMAP Server" -d /var/lib/imap -g mail -G saslauth -s /bin/bash -r cyrus

git config --global http.sslverify false

# Initialise (or update) ClamAV signature database
# We only need the rule for the EICAR test pattern, which seems to be in
# the 'bytecode' database, so keep things fast by only fetching that one.
freshclam --update-db=bytecode
EOF

WORKDIR /srv

RUN <<EOF
# clone CalDAVTester
#
# This isn't needed to run Cyrus, it's a Cyrus's fork of the (possibly
# abandoned?) Apple Calendar and Contacts Server's CAlDAVTester test suite.
# We'll test Cyrus builds against this.
git clone --depth 1 --shallow-submodules https://github.com/cyrusimap/CalDAVTester.git
EOF

# If you want all the cpanm-based installs to run tests, pass:
#   --build-arg CPANM_TEST=1
ARG CPANM_TEST
ENV CPANM_OPT=${CPANM_TEST:--n}
ENV CPANM="cpanm${CPANM_OPT:+ $CPANM_OPT}"

# Set it to "false" to leave all the checkouts and build artifacts in place.
ARG CLEANUP=true

RUN <<EOF
# install Perl prerequisites from CPAN
#
# This is generally stuff not found in Debian, or where we need a newer
# version.
set -e
$CPANM \
  App::Cmd \
  Archive::Tar::Stream \
  Convert::Base64 \
  Data::Printer::Filter::JMAP \
  Data::Printer::Filter::JType \
  Data::Printer::Filter::StructDumb \
  IO::File::fcntl \
  JMAP::Tester~0.109 \
  Mail::IMAPTalk \
  Net::CalDAVTalk~0.14 \
  Net::CardDAVTalk~0.11 \
  Process::Status \
  Test::Unit~0.29 \
  Test::Deep::Hashbag
$CLEANUP && rm -rf ~/.cpanm || true
EOF

RUN <<EOF
# clone and prep JMAP Test Suite
#
# Again, just needed so we can run the tests.
set -e
git clone --depth 1 --shallow-submodules https://github.com/fastmail/JMAP-TestSuite.git
cd JMAP-TestSuite
$CPANM --installdeps .
$CLEANUP && rm -rf ~/.cpanm || true
EOF

RUN <<EOF
# install Mail::JMAPTalk
#
# Another Perl prereq, but this one so new that we expect to need the version
# right from the repo, rather than the latest CPAN release.
set -e
git clone --depth 1 --shallow-submodules https://github.com/cyrusimap/Mail-JMAPTalk.git
cd Mail-JMAPTalk
perl Makefile.PL
make
make test
make install
cd ..
$CLEANUP && rm -rf Mail-IMAPTalk || true
EOF

# This determines what commit (sha1) we use to build Dovecot.  We don't have
# much of a policy about testing or changing this, but: before making changes
# to the Dockerfile or the built image, make sure they don't break things!
ARG DOVECOT_COMMIT=16c850b8d7fa781099315b6a7cc68e6fb5cdeb20
ARG IMAPTEST_COMMIT=0c24edb324f10a08223097b5cda145fa005c4026

RUN <<EOF
# clone and build dovecot.git
#
# This is because we want Dovecot's "imaptest" program for doing testing of our
# IMAP implementation, and it wants Dovecot.
#
# This step is weird.  We want a specific commit, just for the sake of pinning
# to known-good.  We install so that imaptest (below) can rely on the installed
# Dovecot even after we remove the source.  We remove the source because it's a
# whole lot of bytes that we don't really need to ship in the OCI image.
set -e
mkdir dovecot
cd dovecot
git init
git remote add github https://github.com/dovecot/core.git
git fetch --depth 1 github $DOVECOT_COMMIT
git checkout FETCH_HEAD
./autogen.sh
./configure --enable-silent-rules
make -j 8
make install
cd ..
$CLEANUP && rm -rf dovecot || true
EOF

RUN <<EOF
# clone and build imaptest.git
set -e
mkdir imaptest
cd imaptest
git init
git remote add github https://github.com/dovecot/imaptest.git
git fetch --depth 1 github $IMAPTEST_COMMIT
git checkout FETCH_HEAD
./autogen.sh
./configure --enable-silent-rules
make -j 8
# need to run it once as root to link up libs
./src/imaptest || true
EOF

# This determines what branch (head or tag) we use to build cyruslibs.
ARG CYRUSLIBS_BRANCH=master

RUN <<EOF
# clone and build cyruslibs
#
# cyruslibs bundles libraries -- most importantly for Xapian search -- at
# versions newer than Debian ships.  Cyrus builds against these, installed
# under /usr/local/cyruslibs.  This is why `cyd build` points configure's
# CFLAGS/LDFLAGS/PKG_CONFIG_PATH and XAPIAN_CONFIG at that prefix.
set -e
git clone --depth 1 --shallow-submodules -b $CYRUSLIBS_BRANCH \
  https://github.com/cyrusimap/cyruslibs.git
cd cyruslibs
./build.sh
cd ..
$CLEANUP && rm -rf cyruslibs || true
EOF

COPY bin /srv/bin
COPY lib /srv/lib

# Keeping this here for a bit so older cyrus-imapd CI test runs succeed
# but it's no longer needed going forward as test output is in /dev/shm/cass
# now.
RUN mkdir /tmp/cass && chown cyrus:mail /tmp/cass

ADD dot.bashrc /root/.bashrc

# Disable Kernel Log Input module in rsyslog.
RUN sed -i '/imklog/s/^/#/' /etc/rsyslog.conf

ENV PATH="/srv/bin:${PATH}"

CMD ["cyd", "shell"]
