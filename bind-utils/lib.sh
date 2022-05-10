#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   lib.sh of /CoreOS/bind/Library/bind-utils
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
#   library-prefix = bu
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 NAME

bind/bind-utils - Few helpers for working with DNS and DNSSEC in tests.

=head1 DESCRIPTION

This is a trivial example of a BeakerLib library. Its main goal
is to provide a minimal template which can be used as a skeleton
when creating a new library. It implements function fileCreate().
Please note that all library functions must begin with the same
prefix which is defined at the beginning of the library.

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

=item buDIG

Dig tool to use

=back

=cut

buDIG=dig

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head2 buManagedKeys

Obtain managed-keys from given key files.

    buManagedKeys [filename] [...]

=over

=item filename

Full path to key generated using dnssec-keygen.

=back

Managed keys are provided to standard output.

=cut
buManagedKeys()
{
	echo "managed-keys {"
	grep -v '^;' "$@" | while read ZONE CLASS TYPE FLAGS PROTO ALG KEYDATA; do
		echo "$ZONE initial-key $FLAGS $PROTO $ALG \"$KEYDATA\";"
	done
	echo "};"
}

true <<'=cut'
=pod

=head2 buFetchManagedKeys

Obtain managed-keys from given domain.

    buFetchManagedKeys <domain> [server]

=over

=item domain

Zone containing DNSKEY record.

=item server

IP or name of server, which should provide the key.

=back

Managed keys are provided to standard output on success.

=cut
buFetchManagedKeys()
{
	local ZONE="$1"
	local SERVER="${2:+@$2}"
	echo "managed-keys {"
	$buDIG $SERVER +short DNSKEY $ZONE | grep ^257 | while read FLAG PROTO ALG KEY
	do
		echo "$ZONE initial-key $FLAG $PROTO $ALG \"$KEY\";"
	done
	echo "};"
}

true <<'=cut'
=pod

=head2 buZoneGenerateSign

Generate KSK and ZSK for a zone and sign zone file with them

    buZoneGenerateSign -o <zone origin> -f <filename> [-A anchor] [-K keygen flags] [-S sign flags]

=over

=item zone origin

Name of zone, domain name.

=item filename

Full path to zone file

=item anchor

Name of exported anchor file.

If defined, export into $ANCHOR.conf trust anchor in bind managed-keys format.
Into $ANCHOR.key in zone format.

=back

Keys are generated into current directory. Sets KSK and ZSK variables to generated keys.

=cut
buZoneGenerateSign()
{
	local ZONE=
	local FILE=
	local OUTFILE=
	local KEYGEN_ARGS=
	local SIGN_ARGS=
	local ANCHOR=

	#shift; shift
	while getopts 'f:o:A:K:S:' O
	do
		case "$O" in
			o)	ZONE="$OPTARG" ;;
			f)	FILE="$OPTARG" ;;
			A)	ANCHOR="$OPTARG" ;;
			K)	KEYGEN_ARGS="$OPTARG" ;;
			S)	SIGN_ARGS="$OPTARG" ;;
		esac
	done

	KEY=`mktemp $ZONE.key-XXXXXX`
	rlRun "dnssec-keygen $KEYGEN_ARGS -f KSK $ZONE 1>$KEY"
	KSK=`cat $KEY`
	rlRun "dnssec-keygen $KEYGEN_ARGS $ZONE 1>$KEY"
	ZSK=`cat $KEY`
	rm -f $KEY
	rlRun "dnssec-signzone -S -g -o $ZONE $SIGN_ARGS $FILE $KSK $ZSK"
	if [ -n "$ANCHOR" ]; then
		rlRun "buManagedKeys $KSK.key > $ANCHOR.conf"
		rlRun "grep -v '^;' $KSK.key > $ANCHOR.key"
	fi
}

true <<'=cut'
=pod

=head2 buNameservers

Get list of nameservers from resolv.conf

=cut

buNameservers()
{
	awk  '"nameserver" == $1 { print $2 }' /etc/resolv.conf
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

buLibraryLoaded() {
    if rpm=$(rpm -q 'bind-utils'); then
        rlLogDebug "Library bind/bind-utils running with $rpm"
        return 0
    else
        rlLogError "Package bind-utils not installed"
        return 1
    fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Authors
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Petr Mensik <pemensik@redhat.com>

=back

=cut
