#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/bind/Library/bind-utils
#   Description: Few helpers for working with DNS and DNSSEC in tests.
#   Author: Petr Mensik <pemensik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="bind"
PHASE=${PHASE:-Test}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport bind/bind-utils"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
	rlRun "cp /var/named/named.empty $TmpDir"
        rlRun "pushd $TmpDir"
	rlServiceStart rngd
    rlPhaseEnd

    # Create file
    if [[ "$PHASE" =~ "Create" ]]; then
        rlPhaseStartTest "Create"
            fileCreate
        rlPhaseEnd
    fi

    # Self test
    if [[ "$PHASE" =~ "Test" ]]; then
        rlPhaseStartTest "Test signed root"
	    rlRun "buZoneGenerateSign -o . -A root -f named.empty"
	    if [ -x /usr/sbin/dnssec-verify ]; then
	        rlRun "dnssec-verify -o . named.empty.signed"
	    fi
        rlPhaseEnd
    fi

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
	rlServiceRestore rngd
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
