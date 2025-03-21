#!/usr/bin/env bash
#
# ssh-crypt
#
# Bash function to encrypt/decrypt with your ssh-agent private key.
# Requires the commands gzip, ssh-add, ssh-keygen and openssl.
#
# Uses bash-specific extensions like <<<$var to securely pass data.
#
# Wout.Mertens@gmail.com 2021-11-11 - MIT Licensed
#
# Copyright 2021 Wout Mertens
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
# associated documentation files (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge, publish, distribute,
# sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial
# portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
# LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
# NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

ssh-crypt() {
	if [ "$1" != -e ] && [ "$1" != -d ]; then
		echo "Usage: ssh-crypt -<e|d> [seed] [pubkey-match] < infile > outfile" >&2
		echo >&2
		echo "* -e for encrypt, -d for decrypt" >&2
		echo "* seed is used to generate the secret, recommended so you don't use the same secret everywhere" >&2
		echo "* pubkey-match is used to select the first matching pubkey in the ssh-agent" >&2
		echo "* define CRYPT_PUBKEY to provide your own" >&2
		return 2
	fi

	# === Select pubkey
	local pk
	if [ -n "$CRYPT_PUBKEY" ]; then
		pk="$CRYPT_PUBKEY"
	else
		# we can't use ecdsa, it always gives different signatures
		local keys=$(ssh-add -L | grep -v ecdsa)
		if [ -n "$3" ]; then
			keys=$(grep -- "$3" <<<"$keys")
		fi
		read pk <<<"$keys"
	fi
	if [ -z "$pk" ]; then
		echo "!!! Could not select a public key to use - verify ssh-add -L"
		return 1
	fi

	# === Generate secret
	# We pass the pubkey as a file so ssh-keygen will look up the private key in the agent
	local secretText=$(ssh-keygen -Y sign -n hi -q -f /dev/fd/4 4<<<"$pk" <<<"$2")
	if [ $? -ne 0 ] || [ -z "$secretText" ]; then
		echo "!!! Cannot generate secret, is ssh-agent available?" >&2
		return 1
	fi
	# Get it on one line
	local secret=$(openssl dgst -sha512 -r <<<"$secretText")
	if [ $? -ne 0 ] || [ -z "$secret" ]; then
		echo "!!! Cannot generate secret, is openssl available?" >&2
		return 1
	fi

	# === Encrypt/decrypt
	# specify all settings so openssl upgrades don't change encryption
	local opts="-aes-256-cbc -md sha512 -pbkdf2 -iter 239823 -pass fd:4"
	# we use gzip both for compression and detecting bad secrets early
	if [ "$1" = -e ]; then
		gzip | openssl enc -e $opts 4<<<"$secret" | base64
	else
		base64 -d | openssl enc -d $opts 4<<<"$secret" | gzip -d
	fi
}

case "$0" in
	*ssh-crypt*)
		ssh-crypt "$@"
		;;
esac
