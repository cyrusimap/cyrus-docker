# If you change the default source image, update the README, which references
# the underlying Debian version.
ARG DEBIAN_VERSION=bookworm
FROM debian:$DEBIAN_VERSION
LABEL org.opencontainers.image.authors="Cyrus IMAP <docker@role.fastmailteam.com>"

# If you want all the cpanm-based installs to run tests, pass:
#   --build-arg CPANM_TEST=1
ARG CPANM_TEST
ENV CPANM_OPT=${CPANM_TEST:--n}
ENV CPANM="cpanm${CPANM_OPT:+ $CPANM_OPT}"

# Set it to "false" to leave all the checkouts and build artifacts in place.
ARG CLEANUP=true

# This determines what branch (head or tag) we use to build cyruslibs.  We
# would like to be tracking master, but as of this writing (2024-12-09) we need
# to fix a conflict between cyrus-imapd and cyruslibs master branches.
# -- rjbs, 2024-12-09
ARG CYRUSLIBS_BRANCH=cyruslibs-fastmail-v58

# This determines what commit (sha1) we use to build Dovecot.  We don't have
# much of a policy about testing or changing this, but: before making changes
# to the Dockerfile or the built image, make sure they don't break things!
ARG DOVECOT_COMMIT=c6829c3d67fcbc20aa4bb7fb6daed0060e9f6341

RUN <<EOF
# install prerequisites via apt-get
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
    cmake \
    comerr-dev \
    cpanminus \
    debhelper \
    doxygen \
    flex \
    g++ \
    git \
    gperf \
    graphviz \
    groff \
    texi2html \
    texinfo \
    heimdal-dev \
    help2man \
    libanyevent-perl \
    libbsd-dev \
    libbsd-resource-perl \
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
    libjson-perl \
    libjson-xs-perl \
    libldap2-dev \
    libmagic-dev \
    libmilter-dev \
    default-libmysqlclient-dev \
    libnet-server-perl \
    libnews-nntpclient-perl \
    libpath-tiny-perl \
    libpam0g-dev \
    libpcre3-dev \
    libplack-perl \
    libsasl2-dev \
    libsnmp-dev \
    libsqlite3-dev \
    libssl-dev \
    libstring-crc32-perl \
    libtest-deep-perl \
    libtest-most-perl \
    libtest-unit-perl \
    libtest-tcp-perl \
    libtool \
    libunix-syslog-perl \
    liburi-perl \
    libxml-generator-perl \
    libxml-simple-perl \
    libxml-xpath-perl \
    libxml2-dev \
    libwrap0-dev \
    libwww-perl \
    libxapian-dev \
    libzephyr-dev \
    lsb-base \
    net-tools \
    perl \
    php-cli \
    php-curl \
    pkg-config \
    po-debconf \
    python3-docutils \
    python3-pygments \
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
    `# BEGIN for cyrus-docker or just quality of life` \
    libapp-cmd-perl \
    less \
    tini
EOF

RUN <<EOF
# set up users, groups, and config
set -e
groupadd -r saslauth

# The "mail" group exists on stock Debian, we don't need to add it here.
# groupadd -r mail

useradd -c "Cyrus IMAP Server" -d /var/lib/imap -g mail -G saslauth -s /bin/bash -r cyrus

git config --global http.sslverify false
EOF

WORKDIR /srv

RUN <<EOF
# clone CalDAVTester
git clone --depth 1 --shallow-submodules https://github.com/cyrusimap/CalDAVTester.git
EOF

RUN <<EOF
# install Perl prerequisites from CPAN
set -e
$CPANM Mail::IMAPTalk \
       Net::CalDAVTalk \
       Net::CardDAVTalk \
       Convert::Base64 \
       IO::File::fcntl \
       Process::Status \
$CLEANUP && rm -rf ~/.cpanm || true
EOF

RUN <<EOF
# clone and prep JMAP Test Suite
set -e
git clone --depth 1 --shallow-submodules https://github.com/fastmail/JMAP-TestSuite.git
cd JMAP-TestSuite
$CPANM --installdeps .
$CLEANUP && rm -rf ~/.cpanm || true
EOF

RUN <<EOF
# install Mail::JMAPTalk
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

RUN <<EOF
# clone and build dovecot.git
# This one is weird.  We want a specific commit, just for the sake of pinning
# to known-good.  We install so that imaptest (below) can rely on the installed
# Dovecot even after we remove the source.  We remove the source because it's a
# whole lot of bytes that we don't really need to ship in the Docker image.
set -e
mkdir dovecot
cd dovecot
git init
git remote add github https://github.com/dovecot/core.git
# NOTE: change this only after testing
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
git clone --depth 1 --shallow-submodules -b cyrus https://github.com/cyrusimap/imaptest.git
cd imaptest
# RUN git checkout origin/cyrus
sh autogen.sh
./configure --enable-silent-rules
make -j 8
# need to run it once as root to link up libs
./src/imaptest || true
EOF

RUN <<EOF
# clone and build cyruslibs
set -e
git clone --depth 1 --shallow-submodules -b $CYRUSLIBS_BRANCH \
  https://github.com/cyrusimap/cyruslibs.git
cd cyruslibs
# RUN git checkout origin/master
git submodule init
git submodule update
./build.sh
cd ..
$CLEANUP && rm -rf cyruslibs || true
EOF

COPY bin /srv/bin

RUN mkdir /tmp/cass && chown cyrus:mail /tmp/cass

ADD dot.bashrc /root/.bashrc

# Disable Kernel Log Input module in rsyslog.
RUN sed -i '/imklog/s/^/#/' /etc/rsyslog.conf

ENV PATH="/srv/bin:${PATH}"

CMD ["cyd", "shell"]
