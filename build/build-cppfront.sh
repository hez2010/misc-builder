#!/bin/bash

## $1 : version
## $2 : destination: a directory or S3 path (eg. s3://...)
## $3 : last revision successfully build

export PATH="$PATH"

set -ex
ROOT=$(pwd)
VERSION="$1"
LAST_REVISION="$3"

if [[ -z "${VERSION}" ]]; then
    echo Please pass a version to this script
    exit
fi

if echo "${VERSION}" | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    URL=https://github.com/hsutter/cppfront
    BRANCH=main
else
	echo "Versions other than trunk are not currently supported"
	exit 1
fi

FULLNAME=cppfront-${VERSION}.tar.xz
OUTPUT=${ROOT}/${FULLNAME}
S3OUTPUT=
if [[ $2 =~ ^s3:// ]]; then
    S3OUTPUT=$2
else
    if [[ -d "${2}" ]]; then
        OUTPUT=$2/${FULLNAME}
    else
        OUTPUT=${2-$OUTPUT}
    fi
fi

CPPFRONT_REVISION=$(git ls-remote --heads ${URL} refs/heads/${BRANCH} | cut -f 1)
REVISION="cppfront-${CPPFRONT_REVISION}"

echo "ce-build-revision:${REVISION}"
echo "ce-build-output:${OUTPUT}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

SUBDIR=cppfront-${VERSION}
STAGING_DIR=/opt/compiler-explorer/cppfront-${VERSION}
GXXPATH=/opt/compiler-explorer/gcc-12.1.0

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

rm -rf "${SUBDIR}"
git clone -q --depth 1 --single-branch -b "${BRANCH}" "${URL}" "${SUBDIR}"

cd "${SUBDIR}"

"${GXXPATH}/bin/g++" -O2 -std=c++20 -static -o "${STAGING_DIR}/cppfront" source/cppfront.cpp

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" --transform "s,^./,./${SUBDIR}/," -C "${STAGING_DIR}" .

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

echo "ce-build-status:OK"
