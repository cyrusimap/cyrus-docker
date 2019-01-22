#!/bin/bash

source functions.sh

_cyrusclone
_cassandaneclone
_cyrusbuild
_updatejmaptestsuite
_cassandane
_report
