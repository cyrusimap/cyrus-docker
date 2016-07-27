#!/bin/bash

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

# Create 3 as an alias for 1, so the _shell function
# can output data without the caller getting the input.
exec 3>&1

function get_git {
    branch=$3
    if [ -z $branch ]; then
        branch=master
    fi
    if [ ! -d "${1}" ]; then
        git clone -b $branch "${2}" "${1}" || (
            git config --global http.sslverify false
            git clone -b $branch "${2}" "${1}"
        )
    else
        cd ${1}
        git remote set-url origin "${2}"
        git fetch origin
        git reset --hard origin/$branch
    fi
}

function _cassandane {
    pushd /srv/cyrus-imapd.git >&3

    CFLAGS="-g -W -Wall -Wextra -Werror"
    export CFLAGS

    CONFIGOPTS="
        --disable-dependency-tracking
        --enable-autocreate
        --enable-calalarmd
        --enable-coverage
        --enable-gssapi
        --enable-http
        --enable-idled
        --enable-maintainer-mode
        --enable-murder
        --enable-nntp
        --enable-replication
        --enable-shared
        --enable-unit-tests
        --enable-xapian
        --with-ldap=/usr"

    export CONFIGOPTS

    retval=$(_shell tools/build-with-cyruslibs.sh)

    pushd /srv/cassandane.git

    retval=$(_shell make)

    if [ ${retval} -ne 0 ]; then
        echo "WARNING: Could not run Cassandane"
        return 0
    fi

    cp -af cassandane.ini.example cassandane.ini

    retval=$(_shell \
            sed -r -i \
                -e 's|^##rootdir.*$|rootdir=/tmp|g' \
                -e 's|^##prefix.*$|prefix=/usr/cyrus|g' \
                -e '/^#/d' \
                cassandane.ini
        )

    sed -r -i \
        -e '/"-A$af",/d' \
        -e 's| -A$af 2>/dev/null| 2>/dev/null|g' \
        Cassandane/Daemon.pm

    retval=$(_shell ./testrunner.pl -f tap -j $(_num_cpus))

    # /srv/cassandane.git
    popd >&3

    # /srv/cyrus-imapd.git
    popd >&3

    return ${retval}
}

function _num_cpus {
    echo $(cat /proc/cpuinfo | grep ^processor | wc -l)
}

function _report {
    cat ${TMPDIR:-/tmp}/report.log
    rm -rf ${TMPDIR:-/tmp}/report.log
}

function _report_msg {
    printf "%*s" $(( ${BASH_SUBSHELL} * 4 )) " " >> ${TMPDIR:-/tmp}/report.log
    echo "$@" >> ${TMPDIR:-/tmp}/report.log
}

function _shell {
    echo "Running $@ ..." >&3
    $@ >&3 2>&3 ; retval=$?
    if [ ${retval} -eq 0 ]; then
        _report_msg "Running '$@' OK (at $(git rev-parse HEAD))"
        echo "Running $@ OK (at $(git rev-parse HEAD))" >&3
    else
        _report_msg "Running '$@' FAILED (at $(git rev-parse HEAD))"
        echo "Running $@ FAILED (at $(git rev-parse HEAD))" >&3
    fi

    echo ${retval}
}
