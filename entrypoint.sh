#!/bin/bash

git clone https://git.cyrus.foundation/diffusion/I/cyrus-imapd.git /srv/cyrus-imapd.git

# Note: Possibly available variables from Phabricator:
# 
# build.id
# buildable.commit
# buildable.diff
# buildable.revision
# repository.callsign
# repository.uri
# repository.vcs
# step.timestamp
# target.phid
# 

if [ ! -z "${PHABRICATORCERT}" ]; then
    cd /srv
    git clone https://github.com/phacility/libphutil.git
    git clone https://github.com/phacility/arcanist.git

    cat >> /root/.arcrc << EOF
{
  "config": {
    "default": "https:\/\/git.cyrus.foundation\/"
  },
  "hosts": {
    "https:\/\/git.cyrus.foundation\/api\/": {
      "user": "jenkins",
      "cert": "${PHABRICATORCERT}"
    }
  }
}
EOF
fi

cd /srv/cyrus-imapd.git

if [ -z "${DIFFERENTIAL}" ]; then
    if [ ! -z "${COMMIT}" ]; then
        git checkout -f ${COMMIT}
    fi
    
    autoreconf -vi || (libtoolize && autoreconf -vi)
    ./configure \
        --enable-autocreate \
        --enable-coverage \
        --enable-gssapi \
        --enable-http \
        --enable-idled \
        --enable-maintainer-mode \
        --enable-murder \
        --enable-nntp \
        --enable-replication \
        --enable-unit-tests \
        --with-ldap=/usr

    make lex-fix || (make sieve/addr-lex.c sieve/sieve-lex.c && sed -r -i -e 's/int yyl;/yy_size_t yyl;/' -e 's/\tint i;/\tyy_size_t i;/' sieve/addr-lex.c sieve/sieve-lex.c)

    # All is well
    make && make check && exit 0 || exit $?

elif [ ! -z "${DIFFERENTIAL}" ]; then
    cd /srv
    cd /srv/cyrus-imapd.git
    git clean -d -f -x

    if [ ! -z "${COMMIT}" ]; then
        git checkout -f ${COMMIT}
    fi

    wget -q -O- "https://git.cyrus.foundation/${DIFFERENTIAL}?download=true" | patch -p1 || exit 1

    autoreconf -vi || (libtoolize && autoreconf -vi)
    ./configure \
        --enable-autocreate \
        --enable-coverage \
        --enable-gssapi \
        --enable-http \
        --enable-idled \
        --enable-maintainer-mode \
        --enable-murder \
        --enable-nntp \
        --enable-replication \
        --enable-unit-tests \
        --with-ldap=/usr

    make lex-fix || (make sieve/addr-lex.c sieve/sieve-lex.c && sed -r -i -e 's/int yyl;/yy_size_t yyl;/' -e 's/\tint i;/\tyy_size_t i;/' sieve/addr-lex.c sieve/sieve-lex.c)

    make && make check && exit 0 || exit $?
fi
