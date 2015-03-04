#!/bin/bash

git clone https://git.cyrus.foundation/diffusion/I/cyrus-imapd.git /srv/cyrus-imapd.git || (
git config --global http.sslverify false ; git clone https://git.cyrus.foundation/diffusion/I/cyrus-imapd.git /srv/cyrus-imapd.git )

# Note: Possibly available variables from Phabricator:
# 
# build.id              - use this for the container name,
#                         and for providing feedback
# buildable.commit      - we call this ${COMMIT}
# buildable.diff
# buildable.revision    - we call this ${DIFFERENTIAL}
# repository.callsign   - use this to query the commit
# repository.uri
# repository.vcs
# step.timestamp
# target.phid           - we call this ${PHID} (?)
#                         tends to be a harbormaster id
# 

export PATH=$PATH:/srv/arcanist/bin

function commit_raise_concern {
    message=$1

    if [ ! -z "$2" ]; then
        commit=$2
    else
        commit=${COMMIT}
    fi

    if [ -z "$(which arc 2>/dev/null)" ]; then
        return
    fi

    phid=$(echo "{\"commits\":[\"rI${commit}\"]}" | arc call-conduit diffusion.getcommits | awk -v RS=',' -v FS=':' '$1~/\"commitPHID\"/ {print $2}' | tr -d \")

    echo "{\"phid\":\"${phid}\",\"message\":\"${message}\",\"action\":\"concern\"}" | arc call-conduit diffusion.createcomment
}

# Note, since all this builds from GIT, --enable-maintainer-mode
# is required
if [ ! -z "${CONFIGURE_OPTS}" ]; then
    configure_opts=${CONFIGURE_OPTS}
    do_preconfig=1
else
    configure_opts="--enable-autocreate --enable-coverage --enable-gssapi --enable-http --enable-idled --enable-maintainer-mode --enable-murder --enable-nntp --enable-replication --enable-unit-tests --with-ldap=/usr"
    do_preconfig=0
fi

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

    # This may also mean we have a base commit for the diff
    if [ ! -z "${DIFFERENTIAL}" ]; then
        BASE_GIT_COMMIT=$(echo {\"diff_id\": ${DIFF_ID}} | arc call-conduit differential.getdiff | awk -v RS=',' -v FS=':' '$1~/\"sourceControlBaseRevision\"/ {print $2}' | tr -d \")
    fi
fi

cd /srv/cyrus-imapd.git

if [ -z "${DIFFERENTIAL}" ]; then
    if [ ! -z "${COMMIT}" ]; then
        git checkout -f ${COMMIT}
    fi
    
    autoreconf -vi || (libtoolize && autoreconf -vi)

    if [ ${do_preconfig} -eq 1 ]; then
        echo -n "Performing pre-configuration ..."
        ./configure --enable-maintainer-mode 2>&1 > configure.log; retval=$?
        if [ ${retval} -ne 0 ]; then
            echo " FAILED"
            cat configure.log
        fi

        make 2>&1 > make.log; retval=$?
        if [ ${retval} -ne 0 ]; then
            echo " FAILED"
            cat configure.log
        fi

    fi

    ./configure ${configure_opts}

    make lex-fix || (make sieve/addr-lex.c sieve/sieve-lex.c && sed -r -i -e 's/int yyl;/yy_size_t yyl;/' -e 's/\tint i;/\tyy_size_t i;/' sieve/addr-lex.c sieve/sieve-lex.c)

    # All is well
    make && make check && exit 0 || exit $?

elif [ ! -z "${DIFFERENTIAL}" ]; then

    cd /srv
    cd /srv/cyrus-imapd.git
    git clean -d -f -x

    # Someone may still want to build this different
    if [ ! -z "${COMMIT}" ]; then
        git checkout -f ${COMMIT}
    elif [ ! -z "${BASE_GIT_COMMIT}" ]; then
        git checkout -f ${BASE_GIT_COMMIT}
    fi

    # Apply the differential patch
    if [ -z "${PHABRICATORCERT}" ]; then
        wget -q -O- "https://git.cyrus.foundation/D${DIFFERENTIAL}?download=true" | patch -p1 || exit 1
    else
        arc patch --nobranch --nocommit --revision ${DIFFERENTIAL}
    fi

    autoreconf -vi || (libtoolize && autoreconf -vi)

    if [ ${do_preconfig} -eq 1 ]; then
        echo -n "Performing pre-configuration ..."
        ./configure --enable-maintainer-mode 2>&1 > configure.log; retval=$?
        if [ ${retval} -ne 0 ]; then
            echo " FAILED"
            cat configure.log
        fi

        make 2>&1 > make.log; retval=$?
        if [ ${retval} -ne 0 ]; then
            echo " FAILED"
            cat configure.log
        fi

    fi

    ./configure ${configure_opts}

    make lex-fix || (make sieve/addr-lex.c sieve/sieve-lex.c && sed -r -i -e 's/int yyl;/yy_size_t yyl;/' -e 's/\tint i;/\tyy_size_t i;/' sieve/addr-lex.c sieve/sieve-lex.c)

    make && make check && exit 0 || exit $?
fi
