# If you change the default source image, update the README, which references
# the underlying Debian version.
FROM debian:bookworm
LABEL org.opencontainers.image.authors="Cyrus IMAP <docker@role.fastmailteam.com>"

# If you want all the cpanm-based installs to run tests, pass:
#   --build-arg CPANM_TEST=1
ARG CPANM_TEST
ENV CPANM_OPT=${CPANM_TEST:--n}
ENV CPANM="cpanm${CPANM_OPT:+ $CPANM_OPT}"

# This determines what branch (head or tag) we use to build cyruslibs.  We
# would like to be tracking master, but as of this writing (2024-12-09) we need
# to fix a conflict between cyrus-imapd and cyruslibs master branches.
# -- rjbs, 2024-12-09
ARG CYRUSLIBS_BRANCH=cyruslibs-fastmail-v58

# This determines what commit (sha1) we use to build Dovecot.  We don't have
# much of a policy about testing or changing this, but: before making changes
# to the Dockerfile or the built image, make sure they don't break things!
ARG DOVECOT_COMMIT=c6829c3d67fcbc20aa4bb7fb6daed0060e9f6341

# RUN echo 'Acquire::Check-Valid-Until no;' > /etc/apt/apt.conf.d/99no-check-valid-until

# RUN echo "deb http://archive.debian.org/debian/ jessie-backports main contrib" >> /etc/apt/sources.list.d/sources.list

RUN apt-get update && apt-get -y install \
    autoconf \
    automake \
    autotools-dev \
    bash-completion \
    bison \
    build-essential \
    check \
    clang \
    cmake \
    comerr-dev \
    cpanminus \
    doxygen \
    debhelper \
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
    pandoc \
    perl \
    php-cli \
    php-curl \
    pkg-config \
    po-debconf \
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
    zlib1g-dev

# RUN apt-get -t jessie-backports install "cmake" -y

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

RUN git clone --depth 1 --shallow-submodules https://github.com/cyrusimap/CalDAVTester.git \
    caldavtester.git

#RUN cpanm Convert::Color
#RUN cpanm Convert::Color::XTerm
#RUN cpanm Commandable::Invocation
#RUN cpanm Devel::MAT::Dumper
#RUN cpanm Heap
#RUN cpanm List::UtilsBy
#RUN cpanm Module::Pluggable
#RUN cpanm Module::Pluggable::Object
#RUN cpanm Future
#RUN cpanm Future::Utils
#RUN cpanm String::Tagged
#RUN cpanm String::Tagged::Terminal
#RUN cpanm Syntax::Keyword::Try
#RUN cpanm Struct::Dumb
#RUN cpanm Term::ReadLine
#RUN cpanm Mail::IMAPTalk Net::CalDAVTalk Net::CardDAVTalk
#RUN cpanm Convert::Base64 File::LibMagic;
#RUN cpanm Net::LDAP::Constant
#RUN cpanm Net::LDAP::Server
#RUN cpanm Net::LDAP::Server::Test
#RUN cpanm Math::Int64
#RUN cpanm File::Find::Rule
#RUN cpanm Pod::Coverage
#RUN cpanm Test::Pod::Coverage
#RUN cpanm Data::UUID
#RUN cpanm Tie::DataUUID
#RUN cpanm XML::Fast
#RUN cpanm XML::Spice
#RUN cpanm Net::Async::WebSocket::Client

RUN $CPANM Term::ReadLine Mail::IMAPTalk Net::CalDAVTalk Net::CardDAVTalk Convert::Base64 File::LibMagic Net::LDAP::Constant Net::LDAP::Server Net::LDAP::Server::Test Math::Int64 DBD::SQLite IO::File::fcntl Digest::CRC && rm -rf ~/.cpanm

#RUN cpanm --force IO::Async::Notifier
#RUN cpanm IO::Async::OS
#RUN cpanm IO::Async::Stream
#RUN cpanm IO::Async::Loop

WORKDIR /srv
RUN <<EOF
# clone and prep JMAP Test Suite
set -e
git clone --depth 1 --shallow-submodules https://github.com/fastmail/JMAP-TestSuite.git JMAP-TestSuite.git
cd JMAP-TestSuite.git
$CPANM --installdeps .
rm -rf ~/.cpanm
EOF

WORKDIR /srv
RUN <<EOF
# install Mail::JMAPTalk
set -e
git clone --depth 1 --shallow-submodules https://github.com/cyrusimap/Mail-JMAPTalk.git Mail-JMAPTalk.git
cd Mail-JMAPTalk.git
perl Makefile.PL
make
make test
make install
cd ..
rm -rf Mail-IMAPTalk.git
EOF

WORKDIR /srv
RUN <<EOF
# clone and build dovecot.git
# This one is weird.  We want a specific commit, just for the sake of pinning
# to known-good.  We install so that imaptest (below) can rely on the installed
# Dovecot even after we remove the source.  We remove the source because it's a
# whole lot of bytes that we don't really need to ship in the Docker image.
set -e
mkdir dovecot.git
cd dovecot.git
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
rm -rf dovecot.git
EOF

WORKDIR /srv
RUN <<EOF
# clone and build imaptest.git
set -e
git clone --depth 1 --shallow-submodules -b cyrus https://github.com/cyrusimap/imaptest.git imaptest.git
cd imaptest.git
git fetch
# RUN git checkout origin/cyrus
sh autogen.sh
./configure --enable-silent-rules
make -j 8
# need to run it once as root to link up libs
./src/imaptest || true
EOF

WORKDIR /srv
RUN <<EOF
# clone and build cyruslibs
set -e
git clone --depth 1 --shallow-submodules -b $CYRUSLIBS_BRANCH \
  https://github.com/cyrusimap/cyruslibs.git cyruslibs.git
cd cyruslibs.git
git fetch
# RUN git checkout origin/master
git submodule init
git submodule update
./build.sh
cd ..
rm -rf cyruslibs.git
EOF

RUN mkdir /tmp/cass && chown cyrus:mail /tmp/cass

WORKDIR /root
ENV IMAGE=bookworm
ADD https://raw.githubusercontent.com/cyrusimap/cyrus-docker/master/Debian/dot.bashrc /root/.bashrc

WORKDIR /
ADD https://raw.githubusercontent.com/cyrusimap/cyrus-docker/master/Debian/entrypoint.sh /
ADD https://raw.githubusercontent.com/cyrusimap/cyrus-docker/master/Debian/functions.sh /
RUN chmod 755 /entrypoint.sh

# Disable Kernel Log Input module in rsyslog.
RUN sed -i '/imklog/s/^/#/' /etc/rsyslog.conf

CMD ["/entrypoint.sh"]
