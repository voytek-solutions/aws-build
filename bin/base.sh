#!/bin/bash

S3_CONFIG_BUCKET="kingkong.config"

function info { echo -e "\033[1;33m => $1\033[0m"; }

function ok { echo -e "\033[1;32m => $1\033[0m"; }

function error { echo -e "\033[1;31m => Error: $1\033[0m"; }

function die {
	error "$0 - $1"
	exit 1
}

function in_array {
	local -n haystack=$1
	local needle=${2}
	for i in ${!haystack}; do
		if [[ ${i} == ${needle} ]]; then
			return 0
		fi
	done
	return 1
}

function check_s3_bucket_exists {
	local s3_bucket_name
	s3_bucket_name=${1}

	info "Checking if ${s3_bucket_name} bucket exists already"

	set +e
	s3_bucket_exists=$( aws s3 ls s3://"${s3_bucket_name}" 2>&1 )
	set -e

	if [[ "${s3_bucket_exists}" == *"NoSuchBucket"* ]]; then
		return 1
	else
		return 0
	fi
}
