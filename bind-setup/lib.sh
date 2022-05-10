#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   lib.sh of /CoreOS/bind/Library/bind-setup
#   Description: setup functions for bind
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
#   library-prefix = bs
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 NAME

bind/bind-setup - setup functions for bind

=head1 DESCRIPTION

This is basic library for bind settings.

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Variables
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


true <<'=cut'
=pod

=head1 VARIABLES

Below is the list of global variables. When writing a new library,
please make sure that all global variables start with the library
prefix to prevent collisions with other libraries.

=over

=item BIND_CHROOT_PREFIX

=item BIND_DIR

=item BIND_PATH

=back

=cut


#********************************
#Part bind-setup-chroot-functions
BIND_CHROOT_PREFIX=/var/named/chroot
BIND_DIR=${BIND_DIR:-/var/named}
BIND_PATH=




# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'

=head2 bsBindSetupStart

Set the right configuration for actual RHEL distro.

=over

=item named.conf

Optional parameter is custom named.conf file

=item chroot

Chroot status, off or chrootoff to disable, enabled by default.

=back

=cut

bsBindSetupStart() {
    rlServiceStop named
    rlServiceStop named-chroot
    killall -9 named &> /dev/null
    
    bsAssertBindPackages 
    bsBackupConfigs
    # bz605590 -earlier check for redhat-lsb - no need now
    #rlAssertRpm redhat-lsb
    
    if rlIsRHEL 4; then
        bsInstallDefaultRhel4Config
    elif rlIsRHEL 5; then
        bsInstallDefaultRhel5Config
    elif rlIsRHEL 6; then 
        bsInstallDefaultRhel6Config
    elif rlIsRHEL 7 8; then 
        bsInstallDefaultRhel7Config
    else
	# Do not use archive at all
        #bsInstallDefaultRhel7Config
        rlLog "Not using configuration archive"
        bsRemoveConfSetting "dnssec-lookaside"
    fi
    
    if [ "$2" == "off" -o "$2" == "chrootoff" ]; then
        bsChrootDisable
    else bsChrootEnable 
    fi
    
    . /etc/sysconfig/named
     
    if [ ! -z "$1" ]; then
        rm -f /etc/named.conf
        cp "$1" /etc/named.conf &&\
        rlLog "Using custom named config file." 
    fi
}

true <<'=cut'
=head2 bsAssertBindPackages

Assert existence of bind or bind97

=cut

function bsAssertBindPackages() {
    if rpm -q bind97; then
        rlAssertRpm bind97-utils
    else
        rlAssertRpm bind-utils
    fi
}

function bsAssertBindPackagesChroot() {
     if rpm -q bind97; then
        rlAssertRpm bind97-chroot # prepsat do bsChrootEnable
    else
        rlAssertRpm bind-chroot # prepsat do bsChrootEnable
    fi
    
}

true <<'=cut'
=head2 bsCopyConfigsToChroot

Set the chroot configuration for actual RHEL distro.

=cut

function bsCopyConfigsToChroot() {
    if [ ! -z "$ROOTDIR" ]; then
        if rlIsRHEL 4; then
            bsCopyDefaultRhel4ConfigToChroot
        elif rlIsRHEL 5; then
           bsCopyDefaultRhel5ConfigToChroot
        elif rlIsRHEL 6; then
            bsCopyDefaultRhel6ConfigToChroot
        elif rlIsRHEL 7 8; then
            bsCopyDefaultRhel7ConfigToChroot
        else
            bsCopyDefaultRhel7ConfigToChroot
        fi
        for conffile in named.conf rndc.conf rndc.key named.rfc1912.zones; do 
            rm -f $ROOTDIR/etc/$conffile
            cp -f /etc/$conffile $ROOTDIR/etc/$conffile && rlLog "Copying /etc/$conffile to $ROOTDIR/etc/$conffile"
            chmod a+r $ROOTDIR/etc/$conffile
            done
    else
        rlLog "ROOTDIR is not set. So not copying anything to the chroot."
    fi
}
true <<'=cut'
=head2 bsGetDefaultNameServer

Get the nameserver from /etc/resolv.conf and check if it can be resolve.
Deprecated.

=over

=item RHTS_NAMESERVER
Name server from /etc/resolv.conf

=back
=cut

function bsGetDefaultNameServer() {
    RHTS_NAMESERVER=`grep ^nameserver /etc/resolv.conf | head -n 1 | awk '{print $2}'`
    if test -z $RHTS_NAMESERVER; then
        rlRun "false" 0 "Not able to determine default nameserver from /etc/resolv.conf"
    fi
    if ! dig @$RHTS_NAMESERVER ns1.redhat.com > /dev/null; then
        rlRun "false" 0 "Default nameserver $RHTS_NAMESERVER can not resolve ns1.redhat.com."
    fi
    echo $RHTS_NAMESERVER
}

true <<'=cut'
=head2 bsGetNameserversResolvConf

Get nameserver IPs from resolv.conf

=over

=item (optional parameter) alternative resolv.conf path

=back
=cut

function bsGetNameserversResolvConf() {
    local RESOLVCONF=${1:-/etc/resolv.conf}
    awk '$1 == "nameserver" { print $2 }' $RESOLVCONF | xargs echo
}

true <<'=cut'
=head2 bsGetNameservers

Get nameserver IPs from resolv.conf or systemd-resolved if enabled.

=cut

function bsGetNameservers() {
    if [ -x /bin/systemctl ] && systemctl is-enabled systemd-resolved >&/dev/null; then
        resolvectl dns | cut -d: -f2- | xargs echo
    else
	bsGetNameserversResolvConf
    fi
}

true <<'=cut'
=head2 bsGetForwardersConfig

Print forwarders options snippet, forwarder IPs as passed as parameters.

=over

=item [nameserver IP] [...] | first | only

Takes list of forwarders IPs as parameters. Special values first and only are assigned to forward option.
forward only; is default

=back
=cut

function bsGetForwardersConfig() {
    local FORWARD='only'
    echo "	forwarders {"
    for IP in $@
    do
        if [ "$IP" == only -o "$IP" == first ]; then
            FORWARD=$IP
        else
            echo "		${IP};"
        fi
    done
    echo "	};"
    echo "	forward $FORWARD;"
}

true <<'=cut'
=head2 bsBindSetupDone
=cut

function bsBindSetupDone() {
    if [ "$1" != "chroot" ]; then
        rlServiceStart named
    else
        if rlIsRHEL '>=7'; then
            rlServiceStart named-chroot
        else
            rlServiceStart named
        fi
    fi
    echo 'XXXX'
    netstat -tulpn | grep named
    cat /etc/named.conf
}

true <<'=cut'
=head2 bsRemoveConfOptions
=cut

function bsRemoveConfOptions() {
    bsRemoveConfSetting "$1"
}
true <<'=cut'
=head2 bsSetUserOptions
=cut

function bsSetUserOptions() {
    if grep -q '/\* </USEROPTIONS> \*/' /etc/named.conf; then
    	sed -i -e "/\/\* <\/USEROPTIONS> \*\// i $@" /etc/named.conf
    else
	# No prepared archive with configuration exists.
	# Append options to start of options clause
        sed -i -e "/^\s*options\s*{/ a ${@}" /etc/named.conf
    fi
}

true <<'=cut'
=head2 bsFilterDnssecForwarders()

Take list of forwarders IP as parameters.
On each make basic check DNSSEC signatures are present.
Filter out forwarders not returning signatures, print DNSSEC capable on stdout.
Logs also warning with failed forwarders.

=cut

function bsFilterDnssecForwarders() {
    local FAILED=""
    for FORWARDER in $@; do
        if dig +dnssec @$FORWARDER | grep -qiw RRSIG; then
            echo "$FORWARDER "
        else
            FAILED+="$FORWARDER "
	fi
    done
    [ -n "$FAILED" ] && rlLogWarning "Failed DNSSEC forwarders: $FAILED"
}

true <<'=cut'
=head2 bsSetForwarders

Configure forwarders from resolv.conf to bind options.
It would use systemd-resolved if activated.

If parameter is dnssec, it filters obtained forwarders and uses only dnssec capable.

=cut

function bsSetForwarders() {
    local FORWARDERS="$(bsGetNameservers)"
    [ "$1" = dnssec ] && FORWARDERS="$(bsFilterDnssecForwarders $FORWARDERS)"
    local CONFIG="$(bsGetForwardersConfig $FORWARDERS | tr '\n' '\f' | sed -e 's,\f,\\n,g' )"
    rlLog "Setting forwarders to: $FORWARDERS"
    bsSetUserOptions "$CONFIG"
}

true <<'=cut'
=head2 bsRemoveConfSetting
=cut

function bsRemoveConfSetting() {
    TEMP_FILE=`mktemp`
    cat /etc/named.conf | grep -v "$1" > $TEMP_FILE
    cat $TEMP_FILE > /etc/named.conf
    rm -f $TEMP_FILE
}

true <<'=cut'
=head2 bsSetUserSettings
=cut

function bsSetUserSettings() {
    if grep '/\* </USERSETTINGS> \*/' /etc/named.conf >/dev/null; then
         sed -i -e "s,\/\*\ <\/USERSETTINGS>\ \*\/,$1\n&,g" /etc/named.conf
    else
         echo "$@" >> /etc/named.conf
    fi
}

true <<'=cut'
=head2 bsDnssecDisable
=cut

function bsDnssecDisable() {
    if ! rlIsRHEL 3 && ! rlIsRHEL 4 && ! rlIsRHEL 5; then
        bsRemoveConfSetting "dnssec-enable"
        bsRemoveConfSetting "dnssec-validation"
        bsRemoveConfSetting "dnssec-lookaside"
	if ! named -V | grep -E 'BIND 9\.(1[6789]|[23])' > /dev/null; then
	    # BIND 9.16 no longer supports this option
            bsSetUserOptions "dnssec-enable no;"
	fi
        bsSetUserOptions "dnssec-validation no;"
    fi
}
true <<'=cut'
=head2 bsSetLocalResolving
=cut

function bsSetLocalResolving() {
cat > /etc/resolv.conf <<endbsSetLocalResolving
nameserver ::1
nameserver 127.0.0.1
endbsSetLocalResolving
}

true <<'=cut'
=head2 bsBindSetupCleanup
=cut
function bsBindSetupCleanup() {

    if [ "$1" != "chroot" ]; then
        rlServiceStop named
    else
        if rlIsRHEL '>=7'; then
            rlServiceStop named-chroot
        else
            rlServiceStop named
        fi
    fi
    rm -f /var/named/data/named.run
    bsRestoreConfigs
}
#********************************
#Part bind-setup-chroot-functions
#********************************
true <<'=cut'
=head2  bsRootdir
    Return  0  ROOTDIR is defined
            1  ROOTDIR is not defined
=cut

function bsRootdir()
{
    if [ -n "$ROOTDIR" ]; then
        BIND_CHROOT_PREFIX="$ROOTDIR";
        BIND_CHROOT_PREFIX=`echo $BIND_CHROOT_PREFIX | sed 's#//*#/#g;s#/$##'`;
        if [ -L "$BIND_CHROOT_PREFIX" ]; then
            BIND_CHROOT_PREFIX=`/usr/bin/readlink "$BIND_CHROOT_PREFIX"`;
        fi
        return 0;
    fi;
    return 1;
}

true <<'=cut'
=head2 bsChrootEnable
=cut

function bsChrootEnable() {
    bsAssertBindPackagesChroot
    rlLog "Turning on bind chroot."
    bsRootdir;
    if /bin/egrep -q '^ROOTDIR=' /etc/sysconfig/named; then
        /bin/sed -i -e 's#^ROOTDIR=.*$#ROOTDIR='${BIND_CHROOT_PREFIX}'#' /etc/sysconfig/named ;
    else
        echo 'ROOTDIR='${BIND_CHROOT_PREFIX} >> /etc/sysconfig/named;
    fi
}

true <<'=cut'
=head2 bsChrootDisable
=cut

function bsChrootDisable() {
    rlLog "Turning off bind chroot."
    /bin/sed -i -e '/^ROOTDIR=/d' /etc/sysconfig/named;
}


#********************************
#Part bind-setup-configs
#********************************

true <<'=cut'
=head2 bsInstallDefaultGenericConfig

=over

=item First parameter is prefix, the rest are list of files

=back
=cut

function bsInstallDefaultGenericConfig {
    local PREFIX="$1"
    shift
    for MY_TEMP_VAR in "$@"; do
        rm -f "/${MY_TEMP_VAR}"
        cp -f "${PREFIX}/${MY_TEMP_VAR}" "/${MY_TEMP_VAR}" && rlLog "Installing /${MY_TEMP_VAR}"
        chmod a+r "/${MY_TEMP_VAR}"
    done

}

true <<'=cut'
=head2 bsInstallDefaultRhel4Config
=cut

function bsInstallDefaultRhel4Config {
    . /tmp/bind-setup-const.sh
    bsInstallDefaultGenericConfig "${CONFIGS_4_PREFIX}" "${CONFIGS_4[@]}"
    rlLog "Default RHEL4 config files installed..."
}

true <<'=cut'
=head2 bsInstallDefaultRhel5Config
=cut

function bsInstallDefaultRhel5Config {
    . /tmp/bind-setup-const.sh
    bsInstallDefaultGenericConfig "${CONFIGS_5_PREFIX}" "${CONFIGS_5[@]}"
    rlLog "Default RHEL5 config files installed..."
}
true <<'=cut'
=head2 bsInstallDefaultRhel6Config
=cut

function bsInstallDefaultRhel6Config {
    . /tmp/bind-setup-const.sh
    bsInstallDefaultGenericConfig "${CONFIGS_6_PREFIX}" "${CONFIGS_6[@]}"
        
    # see bz677381, 
    if [ ! -e /etc/rndc.key ]; then
        rlLog "Generating rndc key. This will take a while..."
        /usr/sbin/rndc-confgen -a 
    fi 
    [ -x /sbin/restorecon ] && /sbin/restorecon /etc/rndc.* /etc/named.* 
    # rndc.key has to have correct perms and ownership, CVE-2007-6283
    [ -e /etc/rndc.key ] && chown root:named /etc/rndc.key
    [ -e /etc/rndc.key ] && chmod 0640 /etc/rndc.key

    rlLog "Default RHEL6 config files installed..."
}

true <<'=cut'
=head2 bsInstallDefaultRhel7Config
=cut

function bsInstallDefaultRhel7Config {
    . /tmp/bind-setup-const.sh
    bsInstallDefaultGenericConfig "${CONFIGS_7_PREFIX}" "${CONFIGS_7[@]}"
    rlLog "Default RHEL7 config files installed..."
}


true <<'=cut'
=head2 bsCopyDefaultGenericConfigToChroot

=over

=item First parameter is prefix, following with list of files

=back
=cut

function bsCopyDefaultGenericConfigToChroot() {
    local PREFIX="$1"
    shift
    for MY_TEMP_VAR in "$@"; do
        if echo $MY_TEMP_VAR | grep -q "var\/named"; then
            rm -f "${ROOTDIR}/${MY_TEMP_VAR}"
            cp -f "/${MY_TEMP_VAR}" "${ROOTDIR}/${MY_TEMP_VAR}" && rlLog "Copying ${PREFIX}/${MY_TEMP_VAR} to ${ROOTDIR}/${MY_TEMP_VAR}"
            chmod a+r ${ROOTDIR}/${MY_TEMP_VAR}
        fi
    done
}

true <<'=cut'
=head2 bsCopyDefaultRhel4ConfigToChroot
=cut

function bsCopyDefaultRhel4ConfigToChroot() {
    . /tmp/bind-setup-const.sh
    bsCopyDefaultGenericConfigToChroot "${CONFIGS_4_PREFIX}" "${CONFIGS_4[@]}"
    rlLog "Default RHEL4 config files copied to chroot."
}
true <<'=cut'
=head2  bsCopyDefaultRhel5ConfigToChroot
=cut

function bsCopyDefaultRhel5ConfigToChroot() {
    . /tmp/bind-setup-const.sh
    bsCopyDefaultGenericConfigToChroot "${CONFIGS_5_PREFIX}" "${CONFIGS_5[@]}"
    rlLog "Default RHEL5 config files copied to chroot."
}

true <<'=cut'
=head2 bsCopyDefaultRhel6ConfigToChroot
=cut

function bsCopyDefaultRhel6ConfigToChroot() {
    . /tmp/bind-setup-const.sh
    bsCopyDefaultGenericConfigToChroot "${CONFIGS_6_PREFIX}" "${CONFIGS_6[@]}"
    rlLog "Default RHEL6 config files copied to chroot."
}


true <<'=cut'
=head2  bsCopyDefaultRhel7ConfigToChroot
=cut

function bsCopyDefaultRhel7ConfigToChroot() {
    . /tmp/bind-setup-const.sh
    bsCopyDefaultGenericConfigToChroot "${CONFIGS_7_PREFIX}" "${CONFIGS_7[@]}"
    rlLog "Default RHEL7 config files copied to chroot."
}

true <<'=cut'
=head2  bsCopyDefaultRhel8ConfigToChroot
=cut

function bsCopyDefaultRhel8ConfigToChroot() {
    . /tmp/bind-setup-const.sh
    bsCopyDefaultGenericConfigToChroot "${CONFIGS_8_PREFIX}" "${CONFIGS_8[@]}"
    rlLog "Default RHEL8 config files copied to chroot."
}

true <<'=cut'
=head2 bsBundleBindConfigs
=cut

function bsBundleBindConfigs() {
        rlBundleLogs "bind-configs" "/etc/named.conf"
}

true <<'=cut'
=head2 bsGetAllConfigs
=cut

function bsGetAllConfigs() {
    . /tmp/bind-setup-const.sh
    echo "/etc/resolv.conf"
    echo "/etc/sysconfig/named"
    echo "/var/named"
    echo "/etc/named"
    echo "/var/lib/samba/"

    local item

    for item in "${CONFIGS_4[@]}"; do
        echo "/${item}"
    done

    for item in "${CONFIGS_4[@]}"; do
        echo "/var/named/chroot/${item}"
    done

    for item in "${CONFIGS_5[@]}"; do
        echo "/${item}"
    done

    for item in "${CONFIGS_5[@]}"; do
        echo "/var/named/chroot/${item}"
    done

    for item in "${CONFIGS_6[@]}"; do
        echo "/${item}"
    done

    for item in "${CONFIGS_6[@]}"; do
        echo "/var/named/chroot/${item}"
    done
    
    for item in "${CONFIGS_7[@]}"; do
        echo "/${item}"
    done

    for item in "${CONFIGS_7[@]}"; do
        echo "/var/named/chroot/${item}"
    done

}
true <<'=cut'
=head2 bsBackupConfigs
=cut

function bsBackupConfigs() {
    local CONFIFGFILE
    for CONFIFGFILE in `bsGetAllConfigs | sort -u`; do
    #    if test -f $CONFIFGFILE; then
            rlFileBackup --clean $CONFIFGFILE
            rlLog "Backed up $CONFIFGFILE"
       # else
          # CLEANUP="$CLEANUP $CONFIFGFILE"
      #      rlFileBackup --clean $CLEANUP $CONFIGFILE
       #     rlLog "Added $CONFIFGFILE to CLEANUP"
       # fi
    done

     #   rlLog "CLEANUP after backup >${CLEANUP}<"
}
true <<'=cut'
=head2 bsRestoreConfigs
=cut

function bsRestoreConfigs() {
    rlLog "CLEANUP before restore >${CLEANUP}<"
#    rlRun "rm -rf ${CLEANUP}"
    rlFileRestore
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Execution
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 EXECUTION

This library supports direct execution. When run as a task, phases
provided in the PHASE environment variable will be executed.
Supported phases are:

=over

=item Create

Create a new empty file. Use FILENAME to provide the desired file
name. By default 'foo' is created in the current directory.

=item Test

Run the self test suite.

=back

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Verification
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   This is a verification callback which will be called by
#   rlImport after sourcing the library to make sure everything is
#   all right. It makes sense to perform a basic sanity test and
#   check that all required packages are installed. The function
#   should return 0 only when the library is ready to serve.

bsLibraryLoaded() {
    rlLog "true" 0 "Library bind-setup is running"
    rlRun "tar xvzf $(dirname $LIBFILE)/bind-setup.tar.gz"
    cp bind-setup-const.sh /tmp
    return 0
  
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Authors
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 AUTHORS

=over

=item Radka Skvarilova <rskvaril@redhat.com>

Taken source from Martin Cermak <mcermak@redhat.com>

=item Petr Mensik <pemensik@redhat.com>

=back
=cut
