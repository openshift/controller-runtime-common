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

# This script verifies that all specified file types end with a trailing newline.
# It searches for files matching the given patterns (or defaults) and reports
# any files that are missing a final newline character.
#
# Usage: ./verify-trailing-newline.sh [-d <directory>] [-p <pattern>]...
# Example: ./verify-trailing-newline.sh -d ./src -p '*.go' -p '*.yaml'

# shellcheck source=./scripts/utils.sh
source "$(dirname "$0")/utils.sh"

set -o errexit
set -o nounset
set -o pipefail

if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

# Default file patterns to check
DEFAULT_PATTERNS=('*.go' '*.yaml' '*.yml' '*.sh' '*.md' 'Makefile')

# Directories to exclude
EXCLUDE_DIRS=('./vendor' './.git')

function usage {
  local script
  script="$(basename "$0")"
  cat >&2 <<EOF
Usage: ${script} [-d <directory>] [-p <pattern>]...
This script verifies that files end with a trailing newline.

Options:
  -d <directory>  Directory to search (default: current directory)
  -p <pattern>    File pattern to check (can be specified multiple times)
                  Default patterns: ${DEFAULT_PATTERNS[*]}

Examples:
  ${script}
  ${script} -d ./src
  ${script} -p '*.go' -p '*.yaml'
EOF
  exit 1
}

directory="."
patterns=()

while getopts "d:p:h" opt; do
  case "$opt" in
    d) directory="$OPTARG";;
    p) patterns+=("$OPTARG");;
    h) usage;;
    *) usage;;
  esac
done

# Use default patterns if none specified
if [[ ${#patterns[@]} -eq 0 ]]; then
  patterns=("${DEFAULT_PATTERNS[@]}")
fi

# Build find command pattern arguments
pattern_args=()
for i in "${!patterns[@]}"; do
  if [[ $i -gt 0 ]]; then
    pattern_args+=("-o")
  fi
  pattern_args+=("-name" "${patterns[$i]}")
done

# Build exclude arguments
exclude_args=()
for dir in "${EXCLUDE_DIRS[@]}"; do
  exclude_args+=("-not" "-path" "${dir}/*")
done

missing=()
while IFS= read -r -d '' file; do
  # Skip empty files
  if [[ ! -s "$file" ]]; then
    continue
  fi
  # Check if file ends with newline
  if [[ $(tail -c1 "$file" | wc -l) -eq 0 ]]; then
    missing+=("$file")
  fi
done < <(find "$directory" -type f \( "${pattern_args[@]}" \) "${exclude_args[@]}" -print0)

if [[ ${#missing[@]} -gt 0 ]]; then
  echo >&2 "FAIL: The following files are missing a trailing newline:"
  for file in "${missing[@]}"; do
    echo >&2 "  $file"
  done
  exit 1
fi
