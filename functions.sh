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

# List of distributions with applicable diffs
unset ddiffs
unset diffs
declare -a ddiffs
declare -a diffs

# Example:
#ddiffs[${#ddiffs[@]}]="squeeze"   ;   diffs[${#diffs[@]}]="9"

# List of distributions with nono configure options
unset dnopts
unset nopts
declare -a dnopts
declare -a nopts

dnopts[${#dnopts[@]}]="squeeze"   ;   nopts[${#nopts[@]}]="--enable-event-notification"

# If PS1 is set, we're interactive
if [ ! -z "${PS1}" ]; then
    # Set a sensible prompt
    PS1='[\u@${IMAGE} \W]\$ '

    export GIT_PS1_SHOWDIRTYSTATE=1
    export GIT_PS1_SHOWUNTRACKEDFILES=1
    export GIT_PS1_SHOWUPSTREAM="auto verbose"

    if [ ! -f "/etc/bash_completion" ]; then
        if [ -f "/etc/bash_completion.d/git" ]; then
            . /etc/bash_completion.d/git
            PS1='[\u@${IMAGE} \W$(__git_ps1 " (%s)")]\$ '
        fi
    else
        PS1='[\u@${IMAGE} \W$(__git_ps1 " (%s)")]\$ '
    fi

    PROMPT_COMMAND="echo -ne '\033]0;${IMAGE} (in ${HOSTNAME})\007'"

    if [ -f "/usr/share/git-core/contrib/completion/git-prompt.sh" ]; then
        source /usr/share/git-core/contrib/completion/git-prompt.sh
    fi

    # Just so everyone knows where they are, git fetch origin
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

fi

function apply_differential {
    returnval=0
    while [ $# -gt 0 ]; do
        # Apply the differential patch
        if [ -z "${PHAB_CERT}" ]; then
            wget --no-check-certificate -q -O./D${1}.patch \
                "https://git.cyrus.foundation/D${1}?download=true"
            patch -p1 < ./D${1}.patch
            retval=$?
        else
            arc patch --nobranch --nocommit --revision ${1}
            retval=$(find . -type f -name "*.rej" | wc -l)
        fi

        if [ ${retval} -ne 0 ]; then
            returnval=$(( ${returnval} + ${retval} ))
        fi

        shift
    done

    return ${returnval}
}

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
            echo "Step **${step}** succeeded on $(os_version) (image **${IMAGE}**)"
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
            echo -n "This commit **failed step ${step}** on $(os_version) (image **${IMAGE}**)."
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

function _drydock {
    cd /srv/cyrus-imapd.git

    for script in `find contrib/drydock-tests/ -type f -name "*.sh" | sort`; do
        if [ -x $script ]; then
            retval=$(_shell ./$script)
        fi
    done
}

function _cassandane {
    cd /srv/cyrus-imapd.git

    # Surely this doesn't fail?
    retval=$(_shell make clean)

    # Re-configure, no exit code checking, we've already run this.
    retval=$(_shell _configure_maintainer)

    retval=$(_shell _configure \
        --program-prefix= \
        --disable-dependency-tracking \
        --prefix=/usr \
        --exec-prefix=/usr \
        --bindir=/usr/bin \
        --sbindir=/usr/sbin \
        --sysconfdir=/etc \
        --datadir=/usr/share \
        --includedir=/usr/include \
        --libdir=/usr/lib64 \
        --libexecdir=/usr/libexec \
        --localstatedir=/var \
        --sharedstatedir=/var/lib \
        --mandir=/usr/share/man \
        --infodir=/usr/share/info \
        --with-cyrus-prefix=/usr/bin/ \
        --with-service-path=/usr/bin/ \
        --enable-autocreate \
        --enable-coverage \
        --enable-gssapi \
        --enable-http \
        --enable-idled \
        --enable-maintainer-mode \
        --enable-murder \
        --enable-nntp \
        --enable-replication \
        --enable-unit-tests \
        --with-ldap=/usr)

    retval=$(_shell make -j$(_num_cpus))

    retval=$(_shell make install)

    cd /srv/cassandane.git

    retval=$(_shell make)

    if [ ${retval} -ne 0 ]; then
        echo "WARNING: Could not run Cassandane"
        return 0
    fi

    cp -af cassandane.ini.example cassandane.ini

    retval=$(_shell \
            sed -r -i \
                -e 's|^##rootdir.*$|rootdir=/tmp|g' \
                -e 's|^##prefix.*$|prefix=/usr|g' \
                -e '/^#/d' \
                cassandane.ini
        )

    sed -r -i \
        -e '/"-A$af",/d' \
        -e 's| -A$af 2>/dev/null| 2>/dev/null|g' \
        Cassandane/Daemon.pm

    retval=$(_shell ./testrunner.pl -f tap -j $(_num_cpus))
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

    if [ -z "$1" -a -z "${configure_opts}" ]; then
        configure_opts="
                --enable-autocreate \
                --enable-coverage \
                --enable-gssapi \
                --enable-http \
                --enable-idled \
                --enable-maintainer-mode \
                --enable-murder \
                --enable-nntp \
                --enable-replication \
                --enable-unit-tests \
                --with-ldap=/usr"
    elif [ ! -z "$1" ]; then
        configure_opts="$@"
    fi

    retval1=$(_shell autoreconf -vi)

    if [ ${retval1} -eq 0 ]; then
        local _configure_options_real=$(_configure_options ${configure_opts})
        retval4=$(_shell ./configure ${_configure_options_real})
        retval=$(_shell _make_lex_fix)

    # Older platforms, older autoconf, older libtool
    else
        retval2=$(_shell libtoolize)

        if [ ${retval2} -eq 0 ]; then
            retval3=$(_shell autoreconf -vi)

            if [ ${retval3} -eq 0 ]; then
                local _configure_options_real=$(_configure_options ${configure_opts})
                retval4=$(_shell ./configure ${_configure_options_real})

                retval=$(_shell _make_lex_fix)

            # We're not interactive, so check the parent
            elif [ -z "${PS1}" ]; then
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
            else
                return 1
            fi
        # We're not interactive, so check the parent
        elif [ -z "${PS1}" ]; then
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
        else
            return 1
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
            # We're not interactive, so check the parent
            elif [ -z "${PS1}" ]; then
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
            else
                return 1
            fi
        # We're not interactive, so check the parent
        elif [ -z "${PS1}" ]; then
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
        else
            return 1
        fi
    fi

    return 0
}

# Checks options to ./configure and drops those that is known to not
# work for the platform, or only with a differential applied.
function _configure_options {
    _config_opts=""
    _config_nopts=""

    while [ $# -gt 0 ]; do
        case $1 in
            *)
                    retval=$(_find_dnopt $1; echo $?)

                    if [ ${retval} -eq 0 ]; then
                        _config_opts="${_config_opts} $1"
                    else
                        _config_nopts="${_config_nopts} $1"
                    fi

                    shift
                ;;
        esac
    done

    if [ ! -z "${_config_nopts}" ]; then
        echo "WARNING: Configure option(s) suppressed as it is known to fail the build:" >&3
        echo "" >&3
        echo "${_config_nopts}" >&3
        echo "" >&3
        local diffs=$(_find_diffs)
        if [ ! -z "${diffs}" ]; then
            echo "Did you forget to apply a Differential revision?" >&3
            echo "" >&3
            echo "I have ${diffs} marked as applicable to ${IMAGE}" >&3
        fi
    fi

    echo "${_config_opts}"
}

function _find_diffs {
    x=0
    while [ ${x} -lt ${#ddiffs[@]} ]; do
        if [ "${ddiffs[$x]}" == "${IMAGE}" ]; then
            echo "${diffs[$x]}"
        fi
        let x++
    done
}

function _find_dnopt {
    x=0
    while [ ${x} -lt ${#dnopts[@]} ]; do
        if [ "${dnopts[$x]}" == "${IMAGE}" ]; then
            if [ "${nopts[$x]}" == "$1" ]; then
                return 1
            fi
        fi
        let x++
    done

    return 0
}

# Execute 'make' in two different forms: relaxed and tight.
#
# Return codes:
#
#   0   - OK
#   1   - The current commit failed, but the parent also failed
#   2   - The current commit fails this strict, but the parent did not
#   3   - This commit breaks even the relaxed build, while the parent
#         did not.
#
function _make {
    retval=$(_shell _make_relaxed)

    if [ ${retval} -eq 0 ]; then
        retval=$(_shell _make_strict)

        if [ ${retval} -eq 0 ]; then
            # Both makes successful
            return 0
        # We're not interactive, so check the parent
        elif [ -z "${PS1}" ]; then
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
        else
            return 1
        fi
    # We're not interactive, so check the parent
    elif [ -z "${PS1}" ]; then
        # The step failed, so check the parent commit (if
        # we're not already there).
        if [ "$(git rev-parse HEAD)" != "${parent_commit}" ]; then
            retval=$(_shell git checkout ${parent_commit})
            retval=$(_make; echo $?)

            # The parent did not fail this step
            if [ ${retval} -eq 0 ]; then
                return 3
            else
                # The parent failed this step
                return 1
            fi
        else
            # Return failure for parent commit (if not parent commit
            # see above).
            return 1
        fi
    else
        return 1
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
    # We're not interactive, so check the parent
    elif [ -z "${PS1}" ]; then
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
    else
        return 1
    fi

    return 0
}

# Execute relaxed 'make'.
#
# Return codes:
#
#   0   - OK
#   1   - The current commit failed
#
function _make_relaxed {
    # Set relaxed flags
    CFLAGS=""
    export CFLAGS

    # Surely this doesn't fail?
    retval=$(_shell make clean)

    # Re-configure, no exit code checking, we've already run this.
    retval=$(_shell _configure_maintainer)

    # Re-configure, no exit code checking, we've already run this.
    retval=$(_shell _configure)

    retval=$(_shell make -j$(_num_cpus))

    if [ ${retval} -eq 0 ]; then
        _report_msg "make relaxed OK"
    else
        _report_msg "make relaxed FAILED"
    fi

    return ${retval}
}

# Execute strict 'make'.
#
# Return codes:
#
#   0   - OK
#   1   - The current commit failed
#
function _make_strict {
    # Set strict flags
    CFLAGS="-g -W -Wall -Wextra -Werror"
    export CFLAGS

    # Surely this doesn't fail?
    retval=$(_shell make clean)

    # Re-configure, no exit code checking, we've already run this.
    retval=$(_shell _configure_maintainer)

    # Re-configure, no exit code checking, we've already run this.
    retval=$(_shell _configure)

    retval=$(_shell make -j$(_num_cpus))

    if [ ${retval} -eq 0 ]; then
        _report_msg "make strict OK"
    else
        _report_msg "make strict FAILED"
    fi

    return ${retval}
}

function _make_lex_fix {
    if [ ! -f "sieve/addr-lex.c" -o ! -f "sieve/sieve-lex.c" ]; then
        retval=$(_shell make sieve/addr-lex.c sieve/sieve-lex.c)
    fi

    retval=$(_shell make lex-fix)

    # 2.5'ism
    if [ ${retval} -ne 0 ]; then
        retval=$(_shell make sieve/addr-lex.c sieve/sieve-lex.c)
        retval=$(_shell grep -E '^yy_size_t sieveleng;$$' sieve/sieve-lex.c && \
            sed -r -i -e 's/int yyl;/yy_size_t yyl;/g' sieve/sieve-lex.c)

        retval=$(grep -E ' yy_size_t  _yybytes_len ' sieve/sieve-lex.c && \
            sed -r -i -s 's/\tint i;/\tyy_size_t i;/g' sieve/sieve-lex.c)

        retval=$(grep -E ' yy_size_t  _yybytes_len ' sieve/addr-lex.c && \
            sed -r -i -s 's/\tint i;/\tyy_size_t i;/g' sieve/addr-lex.c)
    fi

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
    echo "$@" >> ${TMPDIR:-/tmp}/report.log
}

# Create 3 as an alias for 1, so the _shell function
# can output data without the caller getting the input.
exec 3>&1

function _shell {
    echo "Running $@ ..." >&3
    $@ >&3 2>&3 ; retval=$?
    if [ ${retval} -eq 0 ]; then
        _report_msg "Running '$@' OK"
        echo "Running $@ OK" >&3
    else
        _report_msg "Running '$@' FAILED"
        echo "Running $@ FAILED" >&3
    fi

    echo ${retval}
}

function _test_differentials {
    cd /srv/cyrus-imapd.git

    if [ -z "${PHAB_CERT}" ]; then
        return 0
    fi

    ids=$(echo "{\"status\":\"status-open\",\"paths\":[[\"I\",\"\"]]}" | \
        arc call-conduit differential.query | \
        python -mjson.tool | \
        sed -r \
            -e '/^\s+"id":\s*"[0-9]+",$/!d' \
            -e 's/^\s+"id":\s*"([0-9]+)",/\1/g' | \
        sort --version-sort)

    for id in ${ids}; do
        git clean -d -f -x
        git reset --hard origin/master

        retval=$(_shell apply_differential ${id})
    done
}
