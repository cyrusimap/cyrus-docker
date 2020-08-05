#!/bin/bash

# Create 3 as an alias for 1, so the _shell function
# can output data without the caller getting the input.
exec 3>&1

function _cyrusclone {
    pushd /srv/

    git config --global http.sslverify false
    git clone https://github.com/cyrusimap/cyrus-imapd.git cyrus-imapd.git

    popd >&3
    return 0
}

function _cassandaneclone {
    pushd /srv/

    git config --global http.sslverify false
    git clone https://github.com/cyrusimap/cassandane.git cassandane.git

    popd >&3
    return 0
}

function _cyrusbuild {
    pushd /srv/cyrus-imapd.git >&3

    if [ "$TRAVIS_PULL_REQUEST" = "false" ];
    then
        # Not a pull request
        CYRUSBRANCH=$TRAVIS_BRANCH
        export CYRUSBRANCH
        git fetch
    fi

    if [ "$TRAVIS_PULL_REQUEST" != "false" ];
    then
        # A pull request
        CYRUSBRANCH="PR_TEST_BRANCH"
        export CYRUSBRANCH
        git fetch origin pull/$TRAVIS_PULL_REQUEST/head:$CYRUSBRANCH
    fi

    echo "===> Pulling branch $CYRUSBRANCH..."

    git checkout ${CYRUSBRANCH:-"origin/master"}
    git clean -f -x -d

    CFLAGS="-g -W -Wall -Wextra -Werror"
    export CFLAGS

    CONFIGOPTS="
        --enable-autocreate
        --enable-backup
        --enable-calalarmd
        --enable-gssapi
        --enable-http
        --enable-idled
        --enable-maintainer-mode
        --enable-murder
        --enable-nntp
        --enable-replication
        --enable-shared
        --enable-silent-rules
        --enable-unit-tests
        --enable-xapian
        --enable-jmap
        --with-ldap=/usr"

    export CONFIGOPTS

    retval=$(_shell tools/build-with-cyruslibs.sh)

    # /srv/cyrus-imapd.git
    popd >&3

    return ${retval}
}

function _updatejmaptestsuite {
    pushd /srv/JMAP-TestSuite.git >&3

    git fetch
    git checkout ${JMAPTESTERBRANCH:-"origin/master"}
    git clean -f -x -d
    cpanm --installdeps .

    popd >&3

    return 0
}

function _cassandane {
    pushd /srv/cassandane.git >&3
    git fetch
    git checkout ${CASSANDANEBRANCH:-"origin/master"}
    git clean -f -x -d

    retval=$(_shell make)

    if [ ${retval} -ne 0 ]; then
        echo "WARNING: Could not run Cassandane"
        popd >&3
        return ${retval}
    fi

    cp -af cassandane.ini.dockertests cassandane.ini

    retval=$(_shell ./testrunner.pl -f pretty -j 4 ${CASSANDANEOPTS})

    # /srv/cassandane.git
    popd >&3

    return ${retval}
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
