#!/usr/bin/env bash

# Copyright 2026 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# copied from: https://github.com/kubernetes-sigs/cluster-api/blob/main/hack/verify-shellcheck.sh

# This script verifies that all shell scripts in the repository pass shellcheck
# linting. It automatically downloads the specified version of shellcheck for
# the current OS and architecture if not already present, then runs it against
# all .sh files in the repository.
#
# Usage: ./verify-shellcheck.sh <version>
# Example: ./verify-shellcheck.sh v0.9.0

set -o errexit
set -o nounset
set -o pipefail

if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

if [ $# -ne 1 ]; then
  echo 1>&2 "$0: usage: ./verify-shellcheck.sh <version>"
  exit 2
fi

VERSION=${1}

OS="unknown"
if [[ "${OSTYPE}" == "linux"* ]]; then
  OS="linux"
elif [[ "${OSTYPE}" == "darwin"* ]]; then
  OS="darwin"
fi

ARCH="$(uname -m)"
if [[ "${ARCH}" == "arm64" ]]; then
  # The releases use "aarch64" for ARM
  ARCH="aarch64"
fi

# shellcheck source=scripts/utils.sh
source "$(dirname "$0")/utils.sh"
ROOT_PATH=$(get_root_path)

# create a temporary directory
TMP_DIR=$(mktemp -d)
OUT="${TMP_DIR}/out.log"

# cleanup on exit
cleanup() {
  ret=0
  if [[ -s "${OUT}" ]]; then
    echo "Found errors:"
    cat "${OUT}"
    ret=1
  fi
  rm -rf "${TMP_DIR}"
  exit ${ret}
}
trap cleanup EXIT


SHELLCHECK="${ROOT_PATH}/bin/shellcheck/${VERSION}/shellcheck"

if [ ! -f "$SHELLCHECK" ]; then
  # install buildifier
  cd "${TMP_DIR}" || exit
  DOWNLOAD_FILE="shellcheck-${VERSION}.${OS}.${ARCH}.tar.xz"
  curl -sSL --retry 3 --retry-connrefused --retry-delay 1 "https://github.com/koalaman/shellcheck/releases/download/${VERSION}/${DOWNLOAD_FILE}" -o "${TMP_DIR}/shellcheck.tar.xz"
  tar xf "${TMP_DIR}/shellcheck.tar.xz"
  cd "${ROOT_PATH}"
  mkdir -p "bin/shellcheck/${VERSION}"
  mv "${TMP_DIR}/shellcheck-${VERSION}/shellcheck" "$SHELLCHECK"
fi

cd "${ROOT_PATH}" || exit
FILES=$(find . -name "*.sh")
while read -r file; do
    "$SHELLCHECK" -x "$file" >> "${OUT}" 2>&1
done <<< "$FILES"
