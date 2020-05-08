#!/bin/bash

source functions.sh

echo "[=> 1/6] Updating cyrus-imapd..."
echo "travis_fold:start:clone_cyrus"
_cyrusclone
echo "travis_fold:end:clone_cyrus"

echo "[=> 2/6] Updating cassandane..."
echo "travis_fold:start:clone_cassandane"
_cassandaneclone
echo "travis_fold:end:clone_cassandane"

echo "[=> 3/6] Building cyrus-imapd..."
echo "travis_fold:start:make_and_make_check_cyrus"
_cyrusbuild
retval=$?
echo "travis_fold:end:make_and_make_check_cyrus"
if [ ${retval} -ne 0 ]; then
    exit ${retval}
fi

echo "[=> 4/6] Updating JMAPTestSuite..."
echo "travis_fold:start:update_jmap_test_suite"
_updatejmaptestsuite
echo "travis_fold:end:update_jmap_test_suite"

echo "[=> 5/6] Running Cassandane Tests..."
echo "travis_fold:start:cassandane"
_cassandane
retval=$?
echo "travis_fold:end:cassandane"
if [ ${retval} -ne 0 ]; then
    exit ${retval}
fi

echo "[=> 6/6] Generating Test Report..."
echo "travis_fold:start:test_report"
_report
echo "travis_fold:end:test_report"
exit ${retval}

