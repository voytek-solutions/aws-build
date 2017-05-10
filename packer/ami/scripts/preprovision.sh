#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

function main {
	while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done
	# Need to ensure python is installed so Ansible can run
	sudo apt-get update
	sudo apt-get install -y python2.7
	ln -fs /usr/bin/python2.7 /usr/bin/python
}

main "$@"
