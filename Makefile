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
.PHONY : deps help clean lint

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
deps: .venv ansible/vendor vendor

## Install ansible roles
ansible/vendor:
	ansible-galaxy install -p ansible/vendor -r ansible/vendor.yml --ignore-errors

## Installs a virtual environment and all python dependencies
.venv:
	virtualenv .venv
	.venv/bin/pip install -U pip
	.venv/bin/pip install -r requirements.txt --ignore-installed
	virtualenv --relocatable .venv

## Install vendor dependencies such as Packer
vendor: vendor/packer vendor/jq

# install Packer
vendor/packer:
	mkdir -p vendor
	bash bin/install_local_packer 1.0.0

# install JQ
vendor/jq:
	mkdir -p vendor
	bash bin/install_local_jq 1.15

## Lint bash, python and ansible
lint: lint_bash lint_python lint_ansible

## Lint bash scripts
lint_bash:
	@echo "Bash Lint..."
	@grep -Rn "/bash" bin \
		| grep ":1:" \
		| sed -E 's/([^:]*):.*/\1/' \
		| xargs -I% bash -c 'cd $$(dirname %) && shellcheck -x $(PWD)/%'

## Lint python scripts
lint_python:
	@echo "Python Lint..."
	@grep -Rn python bin \
		| grep ":1:" \
		| sed -E 's/([^:]*):.*/\1/' \
		| xargs -I% pep8 %

## Lint ansible roles and playbooks
lint_ansible:
	@echo "Ansible Roles Lint..."
	@find ansible/roles -name "*.yml" -not -path "*/files/*.yml" -print0 | \
	xargs -n1 -0 -I% \
		ansible-lint %

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

## Builds an AMI using an Ansible role
#
# BUILD_NAME must be specified, in GoCD this should be the
# job number, outside of GoCD a dummy handle should be used
# so as to not collide with GoCD build numbers
#
# Usage:
#  make build ROLE=example BUILD_NAME=test1
ami: secrets.yml
	packer build \
		-var 'aws_instance_type=t2.micro' \
		-var 'aws_region=$(REGION)' \
		-var 'aws_subnet_id=$(shell shyaml get-value aws.build.subnet < secrets.yml)' \
		-var 'aws_vpc_id=$(shell shyaml get-value aws.build.vpc_id < secrets.yml)' \
		-var 'base_ami_id=$(shell shyaml get-value aws.base_ami_id < secrets.yml)' \
		-var 'build_name=$(BUILD_NAME)' \
		-var 'pwd=$(PWD)' \
		-var 'role=$(ROLE)' \
		"packer/ami.json"

## Builds and push docker images
# Usage:
#   make docker ROLE=code_build
docker:
	mkdir -p .artifacts/docker
	packer build \
		-var 'pwd=$(PWD)' \
		-var 'role=$(ROLE)' \
		-var 'version=$(VERSION)' \
		"packer/docker.json"

## Clean up
clean:
	rm -rf .venv
	rm -rf vendor
	rm -rf ansible/vendor
	rm -rf .log

secrets.yml:
	./bin/check_secrets -e $(ENV)

# creates empty `.make` if it does not exist
.make:
	echo "" > .make
