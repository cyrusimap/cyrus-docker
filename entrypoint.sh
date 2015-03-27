#!/bin/bash

# Fedora 21 does not invoke /etc/bashrc, thus giving you a weird PS1
if [ ! -z "$PS1" ]; then
    . /etc/bashrc
fi

if [ ! -d "/srv/cyrus-imapd.git" ]; then
    git clone https://git.cyrus.foundation/diffusion/I/cyrus-imapd.git /srv/cyrus-imapd.git || (
            git config --global http.sslverify false
            git clone https://git.cyrus.foundation/diffusion/I/cyrus-imapd.git /srv/cyrus-imapd.git
        )
else
    cd /srv/cyrus-imapd.git
    git remote set-url origin https://git.cyrus.foundation/diffusion/I/cyrus-imapd.git
    git fetch origin
    git reset --hard origin/master
fi

if [ ! -d "/srv/cassandane.git" ]; then
    git clone https://git.cyrus.foundation/diffusion/C/cassandane.git /srv/cassandane.git || (
            git config --global http.sslverify false
            git clone https://git.cyrus.foundation/diffusion/C/cassandane.git /srv/cassandane.git
        )
else
    cd /srv/cassandane.git
    git remote set-url origin https://git.cyrus.foundation/diffusion/C/cassandane.git
    git fetch origin
    git reset --hard origin/master
fi

cd $HOME

source /functions.sh

# Note, since all this builds from GIT, --enable-maintainer-mode
# is required
if [ ! -z "${CONFIGURE_OPTS}" ]; then
    configure_opts=${CONFIGURE_OPTS}
else
    configure_opts="
            --enable-autocreate \
            --enable-calalarmd \
            --enable-coverage \
            --enable-gssapi \
            --enable-http \
            --enable-idled \
            --enable-maintainer-mode \
            --enable-murder \
            --enable-nntp \
            --enable-replication \
            --enable-shared \
            --enable-unit-tests \
            --enable-xapian \
            --with-ldap=/usr"
fi

if [ ! -z "${PHAB_CERT}" ]; then
    if [ ! -d "/srv/libphutil/" ]; then
        git clone https://github.com/phacility/libphutil.git \
            /srv/libphutil
    fi

    if [ ! -d "/srv/arcanist/" ]; then
        git clone https://github.com/phacility/arcanist.git \
            /srv/arcanist
    fi

    if [ -z "${PHAB_USER}" ]; then
        PHAB_USER="jenkins"
    fi

    cat > /root/.arcrc << EOF
{
  "config": {
    "default": "https:\/\/git.cyrus.foundation\/"
  },
  "hosts": {
    "https:\/\/git.cyrus.foundation\/api\/": {
      "user": "${PHAB_USER}",
      "cert": "${PHAB_CERT}"
    }
  }
}
EOF
    chmod 600 /root/.arcrc
fi

cd /srv/cyrus-imapd.git

if [ -z "${DIFFERENTIAL}" ]; then
    if [ ! -z "${COMMIT}" ]; then
        git checkout -f ${COMMIT}
    fi

    # Store the current and parent commit so we can compare
    current_commit=$(git rev-parse HEAD)
    parent_commit=$(git rev-list --parents -n 1 ${current_commit} | awk '{print $2}')

    export current_commit
    export parent_commit

elif [ ! -z "${DIFFERENTIAL}" ]; then
    # This may also mean we have a base commit for the diff
    if [ ! -z "${PHAB_CERT}" ]; then
        BASE_GIT_COMMIT=$(echo {\"diff_id\": ${DIFF_ID}} | arc call-conduit differential.getdiff | awk -v RS=',' -v FS=':' '$1~/\"sourceControlBaseRevision\"/ {print $2}' | tr -d \")
    fi

    git clean -d -f -x

    # Someone may still want to build this different
    if [ ! -z "${COMMIT}" ]; then
        git checkout -f ${COMMIT}
    elif [ ! -z "${BASE_GIT_COMMIT}" ]; then
        git checkout -f ${BASE_GIT_COMMIT}
    fi

    # Store the current and parent commit so we can compare
    current_commit=$(git rev-parse HEAD)
    parent_commit=$(git rev-list --parents -n 1 ${current_commit} | awk '{print $2}')

    export current_commit
    export parent_commit

    # Apply the differential patch
    apply_differential ${DIFFERENTIAL}

fi

#
# This is the actual legwork
#
_configure || \
    commit_raise_concern --step "configure" --severity $?

# Make twice, one also re-configures with CFLAGS
_make; retval=$?

if [ ${retval} -ne 0 ]; then
    commit_raise_concern --step "make" --severity ${retval}
    _make_relaxed
fi

_make_check || commit_raise_concern --step "make-check" --severity $?

_cassandane || commit_raise_concern --step "cassandane" --severity $?

_test_differentials

echo "=== REPORT ==="

_report
