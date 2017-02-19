include .make

ASSUME_ROLE ?=
ASSUME_SOURCE_PROFILE ?= default
ENV ?= dev
EXTRAS ?=
PATH = $(PWD)/.venv/bin:$(PWD)/vendor:$(PWD)/bin:$(shell printenv PATH)
PROFILE ?=
PWD = $(shell pwd)
REGION ?= eu-west-1
ROLE? =
SECRETS = @secrets.yml
USERNAME ?= ubuntu

export ANSIBLE_CONFIG=ansible/ansible.cfg
export AWS_REGION=$(REGION)
export AWS_DEFAULT_REGION=$(REGION)
export PACKER_LOG=1
export PACKER_LOG_PATH=.log/packer.log
export PATH
export PYTHONUNBUFFERED=1

ifneq ($(PROFILE),)
export AWS_DEFAULT_PROFILE=$(PROFILE)
export AWS_PROFILE=$(PROFILE)
endif

SHELL := env PATH=$(PATH) /bin/bash

.DEFAULT_GOAL := help

## Print this help
help:
	@awk -v skip=1 \
		'/^##/ { sub(/^[#[:blank:]]*/, "", $$0); doc_h=$$0; doc=""; skip=0; next } \
		 skip  { next } \
		 /^#/  { doc=doc "\n" substr($$0, 2); next } \
		 /:/   { sub(/:.*/, "", $$0); printf "\033[34m%-30s\033[0m\033[1m%s\033[0m %s\n\n", $$0, doc_h, doc; skip=1 }' \
		$(MAKEFILE_LIST)

## Assumes role and udpates ~/.aws/credentials
# Run this target befor using tools that can't "assume IAM roles"
# Usage:
#   make assume_role
#   make assume_role ASSUME_ROLE=arn:aws:iam::123456785645:role/Deployments
assume_role:
	@aws sts assume-role \
		--profile $(ASSUME_SOURCE_PROFILE) \
		--output text \
		--role-arn $(ASSUME_ROLE) \
		--role-session-name $(PROFILE)-assumed \
	| tail -1 \
	| awk 'BEGIN{ cmd="aws --profile=$(PROFILE) configure set " } { \
		print cmd "aws_access_key_id " $$2 "\n" \
			cmd "aws_secret_access_key " $$4 "\n" \
			cmd "aws_session_token " $$5 }' \
	| xargs -0 /bin/bash -c
	@sed -ibak -n '/aws_security_token/!p' ~/.aws/credentials
	@awk '{ if ("aws_session_token"==$$1) print $$0 "\naws_security_token = " $$3; else print $$0; }' ~/.aws/credentials > ~/.aws/credentials.tmp
	@mv ~/.aws/credentials.tmp ~/.aws/credentials

## Install local dependencies
deps: deps_python deps_ansible

## Install ansible roles
deps_ansible:
	ansible-galaxy install -p ansible/vendor -r ansible/vendor.yml --ignore-errors

## Installs a virtual environment and all python dependencies
deps_python:
	virtualenv .venv
	.venv/bin/pip install -U pip
	.venv/bin/pip install -r requirements.txt --ignore-installed
	virtualenv --relocatable .venv

## Lint Ansible roles
lint:
	find ansible/roles ansible/playbooks -name "*.yml" -print0 | xargs -n1 -0 -I{} \
		ansible-lint \
			-v \
			--exclude=ansible/vendor \
			{}

## Builds and `ssh` to given machine.
# Startup and (re)provision local VM and then `ssh` to it for given ROLE.
# Example: make vagrant ROLE=example
#          make vagrant ROLE=example MODE=configure
vagrant: vagrant_build
	vagrant ssh

## Builds VM
vagrant_build:
	vagrant up --no-provision
	MODE="$(MODE)" vagrant provision

## Watch changes and rebuild local VM
# Example: make watch ROLE=example
vagrant_watch:
	while sleep 1; do \
		find ansible/ \
			vagrant/ \
			Vagrantfile \
		| entr -d $(MAKE) lint vagrant_build ROLE=$(ROLE); \
	done

## Runs simple command on a given local VM.
# Example: make vagrant_ssh ROLE=example
#          make vagrant_status ROLE=example
#          make vagrant_halt ROLE=example
#          make vagrant_destroy ROLE=example
vagrant_%:
	MODE=$(MODE) vagrant $(subst vagrant_,,$@)

## Clean up
clean:
	rm -rf ansible/vendor
	rm -rf .venv

# creates empty `.make` if it does not exist
.make:
	echo "" > .make
