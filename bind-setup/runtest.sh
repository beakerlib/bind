#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/bind/Library/bind-setup
#   Description: basic test of functions
#   Author: Radka Skvarilova <rskvaril@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc.
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

# Include rhts environment
. /usr/share/beakerlib/beakerlib.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1       
  
#use only in 1minutetip -p "BEAKERLIB_LIBRARY_PATH=/mnt/testarea" rhel6
#uncoment for testing library in local
##########                                
mkdir -p /mnt/testarea/bind/Library
ln -s /mnt/testarea/test /mnt/testarea/bind/Library/bind-setup
######### 

PACKAGE="bind"

rlJournalStart
    rlPhaseStartSetup Setup
        rlRun "TmpDir=\`mktemp -d\`" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"

        rlRun "rlImport bind/bind-setup"
        #for typical test only bsBindSetupStart (need bind-chroot package)
        bsBindSetupStart "" "chrootoff" 
        #bsDnssecDisable
        #bsSetUserOptions "forwarders { `bsGetDefaultNameServer`; };"
        #bsSetUserOptions "forward only;"
	bsSetForwarders
	[ -r /etc/named.root.key ] && bsSetUserSettings 'include "/etc/named.root.key";'
        bsBindSetupDone
	rlRun "cat /etc/named.conf"
    rlPhaseEnd


    rlPhaseStartTest Test
	rlRun "dig @localhost localhost"
	rlRun "rndc status"
	rlRun "dig @localhost redhat.com"
    rlPhaseEnd

    rlPhaseStartCleanup Cleanup
        bsBindSetupCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalEnd
