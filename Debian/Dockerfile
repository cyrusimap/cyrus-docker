FROM debian:jessie
MAINTAINER Cyrus IMAP <docker@role.fastmailteam.com>

RUN echo "deb [check-valid-until=no] http://archive.debian.org/debian jessie-backports main" >> /etc/apt/sources.list.d/sources.list


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
    libdigest-sha-perl \
    libencode-imaputf7-perl \
    libfile-chdir-perl \
    libfile-slurp-perl \
    libglib2.0-dev \
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
    libsasl2-dev \
    libsnmp-dev \
    libsqlite3-dev \
    libssl-dev \
    libstring-crc32-perl \
    libtest-deep-perl \
    libtest-most-perl \
    libtest-unit-perl \
    libtool \
    libunix-syslog-perl \
    liburi-perl \
    libxml-generator-perl \
    libxml-xpath-perl \
    libxml2-dev \
    libwrap0-dev \
    libxapian-dev \
    libzephyr-dev \
    lsb-base \
    net-tools \
    pandoc \
    perl \
    php5-cli \
    php5-curl \
    pkg-config \
    po-debconf \
    python-docutils \
    sudo \
    tcl-dev \
    transfig \
    uuid-dev \
    vim \
    wamerican \
    wget \
    xutils-dev \
    zlib1g-dev

RUN apt-get -t jessie-backports install "cmake" -y

RUN dpkg -l

RUN groupadd -r saslauth ; \
    groupadd -r mail ; \
    useradd -c "Cyrus IMAP Server" -d /var/lib/imap \
    -g mail -G saslauth -s /bin/bash -r cyrus

WORKDIR /srv

RUN git config --global http.sslverify false && \
    git clone https://github.com/cyrusimap/cyruslibs.git \
    cyruslibs.git

RUN git config --global http.sslverify false && \
    git clone https://github.com/dovecot/core.git \
    dovecot.git

RUN git config --global http.sslverify false && \
    git clone https://github.com/cyrusimap/imaptest.git \
    imaptest.git

RUN git config --global http.sslverify false && \
    git clone https://github.com/cyrusimap/CalDAVTester.git \
    caldavtester.git

RUN cpan Term::ReadLine
RUN cpan Mail::IMAPTalk Net::CalDAVTalk Net::CardDAVTalk
RUN cpan Convert::Base64 File::LibMagic;
RUN cpan Net::LDAP::Constant
RUN cpan Net::LDAP::Server
RUN cpan Net::LDAP::Server::Test
RUN cpan Math::Int64


RUN git config --global http.sslverify false && \
    git clone https://github.com/fastmail/JMAP-TestSuite.git \
    JMAP-TestSuite.git

WORKDIR /srv/JMAP-TestSuite.git
RUN cpanm --installdeps .

WORKDIR /srv

RUN git config --global http.sslverify false && \
    git clone https://github.com/cyrusimap/Mail-JMAPTalk.git \
    Mail-JMAPTalk.git
    
WORKDIR /srv/Mail-JMAPTalk.git
RUN perl Makefile.PL
RUN make
RUN make test
RUN make install

WORKDIR /srv/dovecot.git
RUN git fetch
# NOTE: change this only after testing
RUN git checkout 6264b51bcce8ae98efdcda3e55a765d7a13d15ed
RUN ./autogen.sh
RUN ./configure --enable-silent-rules
RUN make -j 8

WORKDIR /srv/imaptest.git
RUN git fetch
RUN git checkout origin/cyrus
RUN sh autogen.sh
RUN ./configure --enable-silent-rules --with-dovecot=/srv/dovecot.git
RUN make -j 8
# need to run it once as root to link up libs
RUN src/imaptest || true

WORKDIR /srv/cyruslibs.git
RUN git fetch
RUN git checkout origin/master
RUN git submodule init
RUN git submodule update
RUN ./build.sh

RUN mkdir /tmp/cass
RUN chown cyrus /tmp/cass

WORKDIR /root
ENV IMAGE jessie
ADD https://raw.githubusercontent.com/cyrusimap/cyrus-docker/master/Debian/dot.bashrc /root/.bashrc

WORKDIR /
ADD https://raw.githubusercontent.com/cyrusimap/cyrus-docker/master/Debian/entrypoint.sh /
ADD https://raw.githubusercontent.com/cyrusimap/cyrus-docker/master/Debian/testscript.sh /
ADD https://raw.githubusercontent.com/cyrusimap/cyrus-docker/master/Debian/functions.sh /
RUN chmod 755 /entrypoint.sh
RUN chmod 755 /testscript.sh
