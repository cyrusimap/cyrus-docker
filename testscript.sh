#!/bin/bash

source functions.sh

get_git /srv/cyrus-imapd.git https://github.com/cyrusimap/cyrus-imapd.git
get_git /srv/cassandane.git https://github.com/cyrusimap/cassandane.git
get_git /srv/cyruslibs.git https://github.com/cyrusimap/cyruslibs.git

cd $HOME

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

cd /srv/cyrus-imapd.git

if [ ! -z "${COMMIT}" ]; then
    git checkout -f ${COMMIT}
fi

# Store the current and parent commit so we can compare
current_commit=$(git rev-parse HEAD)
parent_commit=$(git rev-list --parents -n 1 ${current_commit} | awk '{print $2}')

export current_commit
export parent_commit

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

echo "=== REPORT ==="

_report
