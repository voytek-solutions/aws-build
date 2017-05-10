#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

function main {
	apt-get update

	# Ensure python 2.7
	apt-get install --no-upgrade --show-upgraded --assume-yes \
		python2.7 python-pip
	ln -fs /usr/bin/python2.7 /usr/bin/python

	# Ensure minimal setup
	apt-get install --no-upgrade --assume-yes \
		git curl unzip \
		libffi-dev libssl-dev libyaml-dev libyaml-cpp-dev python-dev \
		python-setuptools python-virtualenv

	apt-get clean
}

main "$@"
