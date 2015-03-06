#!/bin/bash

# Fedora 21 does not invoke /etc/bashrc, thus giving you a weird PS1
if [ ! -z "$PS1" ]; then
    . /etc/bashrc
fi

if [ ! -d /srv/cyrus-imapd.git ]; then
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

# Find the phid for a commit
function commit_phid {
    phid=$(
            echo "{\"commits\":[\"rI${1}\"]}" | \
            arc call-conduit diffusion.getcommits | \
            awk -v RS=',' -v FS=':' '$1~/\"commitPHID\"/ {print $2}' | \
            tr -d \"
        )

    echo ${phid}
}

function commit_comment {

    while [ $# -ne 0 ]; do
        case $1 in
            --step)
                    step=$2
                    shift; shift
                ;;
        esac
    done

    message=$(
            echo "Step **${step}** succeeded on $(os_version)"
        )

    if [ -z "$(which arc 2>/dev/null)" ]; then
        return
    fi

    phid=$(commit_phid ${current_commit})

    echo "{\"phid\":\"${phid}\",\"message\":\"${message}\",\"action\":\"comment\"}" | arc call-conduit diffusion.createcomment
}

function commit_raise_concern {

    while [ $# -ne 0 ]; do
        case $1 in
            --step)
                    step=$2
                    shift; shift
                ;;

            --severity)
                    severity=$2
                    shift; shift
                ;;
        esac
    done

    docs_base_url="https://docs.cyrus.foundation/imap/developer/"

    message=$(
            echo -n "This commit **failed step ${step}** on $(os_version)."
            echo -n '\r\n\r\n'
            echo -n "NOTE: See ${docs_base_url}/${step}-fails.html for details."
            echo -n '\r\n\r\n'
            echo -n "Additional information:"
            echo -n '\r\n\r\n'
            if [ ${severity} -eq 1 ]; then
                echo -n "  * The parent commit rI${parent_commit} also failed this step, so you're OK."
            elif [ ${severity} -eq 2 ]; then
                echo -n "  * The parent commit rI${parent_commit} **did not fail** this step. Presumably, this is all your fault (or mine)."
            elif [ ${severity} -eq 3 ]; then
                echo -n "  * I did not check a parent commit, the return code applies to a //relaxed// build failing. This must be fixed."
            fi
        )

    if [ -z "$(which arc 2>/dev/null)" ]; then
        return
    fi

    phid=$(commit_phid ${current_commit})

    if [ ${severity} -eq 1 ]; then
        # Really, this is a comment
        echo "{\"phid\":\"${phid}\",\"message\":\"${message}\",\"action\":\"comment\"}" | arc call-conduit diffusion.createcomment
    else
        echo "{\"phid\":\"${phid}\",\"message\":\"${message}\",\"action\":\"concern\"}" | arc call-conduit diffusion.createcomment
    fi
}

function commit_thumbs_up {
    echo "Would have put my thumbs up"
}

function differential_raise_concern {
    echo "Would have raised a concern"
}

function os_version {
    if [ -f "/etc/lsb-release" ]; then
        . /etc/lsb-release
        echo "${DISTRIB_ID} ${DISTRIB_RELEASE} (${DISTRIB_CODENAME})"
    elif [ -f "/etc/debian_version" ]; then
        echo "Debian $(cat /etc/debian_version)"
    elif [ -f "/etc/system-release" ]; then
        cat /etc/system-release
    fi
}

# A simple routine that runs:
#
#   auto(re)conf/libtoolize
#   ./configure ${CONFIGURE_OPTS}
#
function _configure {
    # Initialize variables
    retval1=0   # The initial autoreconf return code
    retval2=0   # The fallback libtoolize return code
    retval3=0   # The fallback autoreconf return code
    retval4=0   # The actual configure command

    retval1=$(_shell autoreconf -vi)

    if [ ${retval1} -eq 0 ]; then
        retval4=$(_shell ./configure ${configure_opts})

    # Older platforms, older autoconf, older libtool
    else
        retval2=$(_shell libtoolize)

        if [ ${retval2} -eq 0 ]; then
            retval3=$(_shell autoreconf -vi)

            if [ ${retval3} -ne 0 ]; then
                retval4=$(./configure ${configure_opts})
            else
                if [ "$(git rev-parse HEAD)" != "${parent_commit}" ]; then
                    retval=$(_shell git checkout ${parent_commit})
                    retval=$(_configure; echo $?)

                    if [ ${retval} -eq 0 ]; then
                        return 2
                    else
                        return 1
                    fi

                else
                    return 1
                fi
            fi
        else
            if [ "$(git rev-parse HEAD)" != "${parent_commit}" ]; then
                retval=$(_shell git checkout ${parent_commit})
                retval=$(_configure; echo $?)

                if [ ${retval} -eq 0 ]; then
                    return 2
                else
                    return 1
                fi

            else
                return 1
            fi
        fi
    fi

    return 0
}

# A simple routine that runs:
#
#   auto(re)conf/libtoolize
#   ./configure --enable-maintainer
#
# which should succeed, but it it fails, needs to be tested against the
# parent commit, because if that commit fails too, then this commit is
# not to blame.
#
# Only executed if pre-existing configure flags are passed.
#
# Return codes:
#
#   0   - OK
#   1   - The current commit failed, but the parent also failed
#   2   - The current commit fails this step, but the parent did not
#
function _configure_maintainer {
    # Initialize variables
    retval1=0   # The initial autoreconf return code
    retval2=0   # The fallback libtoolize return code
    retval3=0   # The fallback autoreconf return code
    retval4=0   # The actual configure command

    retval1=$(_shell autoreconf -vi)

    if [ ${retval1} -eq 0 ]; then
        retval4=$(_shell ./configure --enable-maintainer-mode)

    # Older platforms, older autoconf, older libtool
    else
        retval2=$(_shell libtoolize)

        if [ ${retval2} -eq 0 ]; then
            retval3=$(_shell autoreconf -vi)

            if [ ${retval3} -ne 0 ]; then
                retval4=$(./configure --enable-maintainer-mode)
            else
                if [ "$(git rev-parse HEAD)" != "${parent_commit}" ]; then
                    retval=$(_shell git checkout ${parent_commit})
                    retval=$(_configure_maintainer; echo $?)

                    if [ ${retval} -eq 0 ]; then
                        return 2
                    else
                        return 1
                    fi
                else
                    return 1
                fi
            fi
        else
            if [ "$(git rev-parse HEAD)" != "${parent_commit}" ]; then
                retval=$(_shell git checkout ${parent_commit})
                retval=$(_configure_maintainer; echo $?)

                if [ ${retval} -eq 0 ]; then
                    return 2
                else
                    return 1
                fi
            else
                return 1
            fi
        fi
    fi

    make \
        imap/rfc822_header.c \
        imap/rfc822_header.h || return 1

    return 0
}

# Execute 'make' in two different forms: relaxed and tight.
#
# Return codes:
#
#   0   - OK
#   1   - The current commit failed, but the parent also failed
#   2   - The current commit fails this step, but the parent did not
#   3   - This commit breaks even the relaxed build
#
function _make {
    # First, compile without extra CFLAGS. This tells us the difference.
    export CFLAGS=""

    retval=$(_shell make)

    if [ ${retval} -eq 0 ]; then
        # Tighten the flags
        export CFLAGS="-g -fPIC -W -Wall -Wextra -Werror"

        # Surely this doesn't fail?
        retval=$(_shell make clean)

        # Re-configure, no exit code checking, we've already run this.
        retval=$(_shell _configure_maintainer)

        # Re-configure, no exit code checking, we've already run this.
        retval=$(_shell _configure)

        # Now for the interesting part
        retval=$(_shell make)

        if [ ${retval} -eq 0 ]; then
            # Both makes successful
            return 0
        else
            # The step failed, so check the parent commit (if
            # we're not already there).
            if [ "$(git rev-parse HEAD)" != "${parent_commit}" ]; then
                retval=$(_shell git checkout ${parent_commit})
                retval=$(_make; echo $?)

                # The parent did not fail this step
                if [ ${retval} -eq 0 ]; then
                    return 2
                else
                    # The parent failed this step
                    return 1
                fi
            else
                # Return failure for parent commit (if not parent commit
                # see above).
                return 1
            fi
        fi
    else
        # What?
        return 3
    fi

    return 0
}

# Execute 'make-check'
#
# Return codes:
#
#   0   - OK
#   1   - The current commit failed, but the parent also failed
#   2   - The current commit fails this step, but the parent did not
#
function _make_check {
    # First, compile without extra CFLAGS. This tells us the difference.
    retval=$(_shell make check)

    if [ ${retval} -eq 0 ]; then
        return 0
    else
        # The current commit failed, so check the parent commit (if
        # we're not already there).
        if [ "$(git rev-parse HEAD)" != "${parent_commit}" ]; then
            retval=$(_shell git checkout ${parent_commit})
            retval=$(_make_check; echo $?)

            # The parent commit did not fail make check
            if [ ${retval} -eq 0 ]; then
                return 2
            else
                return 1
            fi
        else
            # Return failure for parent commit
            return 1
        fi
    fi

    return 0
}

function _make_lex_fix {
    retval=$(_shell make lex-fix)

    # 2.5'ism
    if [ ${retval} -ne 0 ]; then
        retval=$(_shell make sieve/addr-lex.c sieve/sieve-lex.c && sed -r -i -e 's/int yyl;/yy_size_t yyl;/' -e 's/\tint i;/\tyy_size_t i;/' sieve/addr-lex.c sieve/sieve-lex.c)
    fi

    return ${retval}
}

# Create 3 as an alias for 1, so the _shell function
# can output data without the caller getting the input.
exec 3>&1

function _shell {
    echo "Running $@ ..." >&3
    $@ >&3 2>&3 ; retval=$?
    if [ ${retval} -eq 0 ]; then
        echo "Running $@ OK" >&3
    else
        echo "Running $@ FAILED" >&3
    fi

    echo ${retval}
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

if [ ! -z "${PHAB_CERT}" ]; then

    if [ -z "$(which arc)" ]; then
        cd /srv

        if [ ! -d libphutil ]; then
            git clone https://github.com/phacility/libphutil.git
        fi

        if [ ! -d arcanist ]; then
            git clone https://github.com/phacility/arcanist.git
        fi
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

    if [ ${do_preconfig} -eq 1 ]; then
        echo "Performing pre-configuration ..."
        _configure_maintainer || \
            commit_raise_concern --step "pre-configure" --severity $?
    fi

    _configure || \
        commit_raise_concern --step "configure" --severity $?

    # We sort of trust this
    _make_lex_fix || \
        commit_raise_concern --step "make-lex-fix" --severity $?

    # Make twice, one also re-configures with CFLAGS
    _make && commit_comment --step "make" ; retval=$?

    if [ ${retval} -ne 0 ]; then
        commit_raise_concern --step "make" --severity ${retval}
        exit 1
    fi

    _make_check && commit_comment --step "make-check" || commit_raise_concern --step "make-check" --severity $?

elif [ ! -z "${DIFFERENTIAL}" ]; then
    # This may also mean we have a base commit for the diff
    if [ ! -z "${PHAB_CERT}" ]; then
        BASE_GIT_COMMIT=$(echo {\"diff_id\": ${DIFF_ID}} | arc call-conduit differential.getdiff | awk -v RS=',' -v FS=':' '$1~/\"sourceControlBaseRevision\"/ {print $2}' | tr -d \")
    fi

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
    if [ -z "${PHAB_CERT}" ]; then
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
