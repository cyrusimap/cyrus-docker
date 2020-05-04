#!/bin/bash

source functions.sh

_cyrusclone
_cassandaneclone
_cyrusbuild
retval=$?
if [ ${retval} -ne 0 ]; then
    exit ${retval}
fi
_updatejmaptestsuite
_cassandane
retval=$?
_report
exit ${retval}

