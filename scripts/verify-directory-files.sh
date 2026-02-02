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

# This script verifies that a directory only contains allowed files.
# It checks all files in the specified directory against a list of allowed filenames.
#
# Usage: ./verify-directory-files.sh -d <directory> <allowed_file1> [allowed_file2] ...
# Example: ./verify-directory-files.sh -d tools go.tool.mod go.tool.sum README.md

set -o errexit
set -o nounset
set -o pipefail

if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

TARGET_DIR=""
ALLOWED_FILES=()

function usage {
  local script
  script="$(basename "$0")"
  cat >&2 <<EOF
Usage: ${script} -d <directory> <allowed_file1> [allowed_file2] ...
This script verifies that a directory only contains the specified allowed files.
-d <directory>
  Directory to check (required)
<allowed_file1> [allowed_file2] ...
  List of allowed filenames (at least one required)
Examples:
  ${script} -d tools go.tool.mod go.tool.sum README.md
  ${script} -d ./scripts *.sh utils.sh
EOF
  exit 1
}

while getopts d:h opt; do
  case "$opt" in
    d) TARGET_DIR="$OPTARG";;
    h) usage;;
    *) usage;;
  esac
done

# Shift past the options to get the allowed files
shift $((OPTIND - 1))

# Collect allowed files from remaining arguments
while [[ $# -gt 0 ]]; do
  ALLOWED_FILES+=("$1")
  shift
done

if [[ -z "${TARGET_DIR}" ]]; then
  echo >&2 "ERROR: -d <directory> is required"
  usage
fi

if [[ ${#ALLOWED_FILES[@]} -eq 0 ]]; then
  echo >&2 "ERROR: At least one allowed file must be specified"
  usage
fi

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo >&2 "FAIL: Directory ${TARGET_DIR} does not exist"
  exit 1
fi

# Find all files in the target directory
found_files=$(find "${TARGET_DIR}" -type f -maxdepth 1 2>/dev/null | sort || true)

if [[ -z "${found_files}" ]]; then
  echo >&2 "FAIL: Directory ${TARGET_DIR} is empty"
  exit 1
fi

# Check each file
invalid_files=()
while IFS= read -r file; do
  if [[ -z "${file}" ]]; then
    continue
  fi
  filename=$(basename "${file}")
  allowed=false
  for allowed_file in "${ALLOWED_FILES[@]}"; do
    # Support glob patterns (e.g., *.sh) using case statement
    # shellcheck disable=SC2254 # We intentionally want glob matching here
    case "${filename}" in
      ${allowed_file})
        allowed=true
        break
        ;;
    esac
  done
  if [[ "${allowed}" == "false" ]]; then
    invalid_files+=("${file}")
  fi
done <<< "${found_files}"

if [[ ${#invalid_files[@]} -gt 0 ]]; then
  echo >&2 "FAIL: Found disallowed files in ${TARGET_DIR} directory:"
  for file in "${invalid_files[@]}"; do
    echo >&2 "  ${file}"
  done
  echo >&2 ""
  echo >&2 "The ${TARGET_DIR} directory should only contain:"
  for allowed_file in "${ALLOWED_FILES[@]}"; do
    echo >&2 "  - ${allowed_file}"
  done
  echo >&2 "Please remove these files or move them to an appropriate location."
  exit 1
fi
