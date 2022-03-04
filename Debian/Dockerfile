FROM debian:buster
MAINTAINER Cyrus IMAP <docker@role.fastmailteam.com>

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
    python-docutils \
    python-sphinx \
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

RUN dpkg -l

RUN groupadd -r saslauth ; \
    groupadd -r mail ; \
    useradd -c "Cyrus IMAP Server" -d /var/lib/imap \
    -g mail -G saslauth -s /bin/bash -r cyrus

RUN service rsyslog start

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

#RUN cpanm install Convert::Color
#RUN cpanm install Convert::Color::XTerm
#RUN cpanm install Commandable::Invocation
#RUN cpanm install Devel::MAT::Dumper
#RUN cpanm install Heap
#RUN cpanm install List::UtilsBy
#RUN cpanm install Module::Pluggable
#RUN cpanm install Module::Pluggable::Object
#RUN cpanm install Future
#RUN cpanm install Future::Utils
#RUN cpanm install String::Tagged
#RUN cpanm install String::Tagged::Terminal
#RUN cpanm install Syntax::Keyword::Try
#RUN cpanm install Struct::Dumb
#RUN cpanm install Term::ReadLine
#RUN cpanm install Mail::IMAPTalk Net::CalDAVTalk Net::CardDAVTalk
#RUN cpanm install Convert::Base64 File::LibMagic;
#RUN cpanm install Net::LDAP::Constant
#RUN cpanm install Net::LDAP::Server
#RUN cpanm install Net::LDAP::Server::Test
#RUN cpanm install Math::Int64
#RUN cpanm install File::Find::Rule
#RUN cpanm install Pod::Coverage
#RUN cpanm install Test::Pod::Coverage
#RUN cpanm install Data::UUID
#RUN cpanm install Tie::DataUUID
#RUN cpanm install XML::Fast
#RUN cpanm install XML::Spice
#RUN cpanm install Net::Async::WebSocket::Client

RUN cpanm install Term::ReadLine
RUN cpanm install Mail::IMAPTalk Net::CalDAVTalk Net::CardDAVTalk
RUN cpanm install Convert::Base64 File::LibMagic;
RUN cpanm install Net::LDAP::Constant
RUN cpanm install Net::LDAP::Server
RUN cpanm install Net::LDAP::Server::Test
RUN cpanm install Math::Int64
RUN cpanm install DBD::SQLite

#RUN cpanm install --force IO::Async::Notifier
#RUN cpanm install IO::Async::OS
#RUN cpanm install IO::Async::Stream
#RUN cpanm install IO::Async::Loop


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
ENV IMAGE buster
ADD https://raw.githubusercontent.com/cyrusimap/cyrus-docker/master/Debian/dot.bashrc /root/.bashrc

WORKDIR /
ADD https://raw.githubusercontent.com/cyrusimap/cyrus-docker/master/Debian/entrypoint.sh /
ADD https://raw.githubusercontent.com/cyrusimap/cyrus-docker/master/Debian/functions.sh /
RUN chmod 755 /entrypoint.sh
