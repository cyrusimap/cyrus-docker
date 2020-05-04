#!/bin/bash

source functions.sh

echo "Updating cyrus-imapd..."
_cyrusclone

echo "Updating cassandane..."
_cassandaneclone

echo "Building cyrus-imapd..."
_cyrusbuild
retval=$?
if [ ${retval} -ne 0 ]; then
    exit ${retval}
fi

echo "Updating JMAPTestSuite..."
_updatejmaptestsuite

echo "Running Cassandane Tests..."
_cassandane
retval=$?
if [ ${retval} -ne 0 ]; then
    exit ${retval}
fi

echo "Generating Test Report..."
_report
exit ${retval}
