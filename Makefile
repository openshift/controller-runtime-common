# Copyright 2026 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# If you update this file, please follow
# https://www.thapaliya.com/en/writings/well-documented-makefiles/

#
# Go.
#
GO_DIRECTIVE_VERSION ?= 1.24.0

# Active module mode, as we use go modules to manage dependencies
export GO111MODULE=on

#
# Kubebuilder.
#
export KUBEBUILDER_ENVTEST_KUBERNETES_VERSION ?= 1.34.1
export KUBEBUILDER_CONTROLPLANE_START_TIMEOUT ?= 60s
export KUBEBUILDER_CONTROLPLANE_STOP_TIMEOUT ?= 60s

# Enables shell script tracing. Enable by running: TRACE=1 make <target>
TRACE ?= 0

# Directories.
#
# Full directory of where the Makefile resides
ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
BIN_DIR := $(abspath $(ROOT_DIR)/bin)
TOOLS_DIR := $(abspath $(ROOT_DIR)/tools)
GO_INSTALL := ./scripts/go_install.sh

export PATH := $(abspath $(BIN_DIR)):$(PATH)

# Set GOMODCACHE to a stable temporary location if not already set
# This prevents permission issues in CI environments where HOME might not be set
# Uses a stable tmp directory name so it persists across invocations
GOMODCACHE ?= /tmp/.gomodcache-controller-runtime-common
export GOMODCACHE

#
# Ginkgo configuration.
#
GINKGO_FOCUS ?=
GINKGO_SKIP ?=
GINKGO_LABEL_FILTER ?=
GINKGO_NODES ?= 1
GINKGO_TIMEOUT ?= 3h
GINKGO_ARGS ?=
GINKGO_POLL_PROGRESS_AFTER ?= 60m
GINKGO_POLL_PROGRESS_INTERVAL ?= 5m
SKIP_RESOURCE_CLEANUP ?= false
USE_EXISTING_CLUSTER ?= false
GINKGO_NOCOLOR ?= false

# to set multiple ginkgo skip flags, if any
ifneq ($(strip $(GINKGO_SKIP)),)
_SKIP_ARGS := $(foreach arg,$(strip $(GINKGO_SKIP)),-skip="$(arg)")
endif

#
# Tools.
#

SHELLCHECK_VER := v0.10.0

# Most of the tools are defined and managed in tools/go.tool.mod
GOLANGCI_LINT := go tool -modfile=$(TOOLS_DIR)/go.tool.mod golangci-lint
GO_APIDIFF := go tool -modfile=$(TOOLS_DIR)/go.tool.mod go-apidiff
SETUP_ENVTEST := go tool -modfile=$(TOOLS_DIR)/go.tool.mod setup-envtest

# Note: Need to use abspath so we can invoke these from subdirectories
# Helper function to get dependency version from go.mod
get_go_version = $(shell go list -m $1 | awk '{print $$2}')
# We need to load the version of ginkgo from go.mod rather than from go.tool.mod
# so we keep the same version used in the test codebase in sync with the one used to run the tests.
GINKGO_BIN := ginkgo
GINKGO_VER := $(call get_go_version,github.com/onsi/ginkgo/v2)
GINKGO := $(abspath $(BIN_DIR)/$(GINKGO_BIN)-$(GINKGO_VER))
GINKGO_PKG := github.com/onsi/ginkgo/v2/ginkgo

#
# Top Level targets.
#

all: test

.PHONY: help
help:  # Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[0-9A-Za-z_-]+:.*?##/ { printf "  \033[36m%-50s\033[0m %s\n", $$1, $$2 } /^\$$\([0-9A-Za-z_-]+\):.*?##/ { gsub("_","-", $$1); printf "  \033[36m%-50s\033[0m %s\n", tolower(substr($$1, 3, length($$1)-7)), $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

## --------------------------------------
## Lint / Verify
## --------------------------------------

##@ lint and verify:

.PHONY: lint
lint:  ## Lint the codebase
	$(GOLANGCI_LINT) run -v $(GOLANGCI_LINT_EXTRA_ARGS)

.PHONY: verify
verify: verify-go-directive verify-go-mod-tidy verify-tools-directory verify-trailing-newline verify-shellcheck ## Run all verify-* targets

.PHONY: verify-go-directive
verify-go-directive: ## Verify go directive in go.mod files
	@echo "Verifying go directive in go.mod"
	@TRACE=$(TRACE) ./scripts/verify-go-directive.sh -g $(GO_DIRECTIVE_VERSION)
	@echo "Verifying go directive in tools/go.tool.mod"
	@TRACE=$(TRACE) ./scripts/verify-go-directive.sh -g $(GO_DIRECTIVE_VERSION) -d $(TOOLS_DIR)

.PHONY: verify-go-mod-tidy
verify-go-mod-tidy: ## Verify go.mod and tools/go.tool.mod (and their .sum files) are tidy
	@echo "Verifying go.mod is tidy..."
	@go mod tidy
	@if ! git diff --quiet go.mod go.sum; then \
		echo "ERROR: go.mod or go.sum is not tidy. Run 'go mod tidy' to fix."; \
		git --no-pager diff go.mod go.sum; \
		exit 1; \
	fi
	@echo "Verifying tools/go.tool.mod is tidy..."
	@cd tools && go mod tidy
	@if ! git diff --quiet tools/go.tool.mod tools/go.tool.sum; then \
		echo "ERROR: tools/go.tool.mod or tools/go.tool.sum is not tidy. Run 'cd tools && go mod tidy' to fix."; \
		git --no-pager diff tools/go.tool.mod tools/go.tool.sum; \
		exit 1; \
	fi

.PHONY: verify-tools-directory
verify-tools-directory: ## Verify tools directory only contains allowed files
	@echo "Verifying tools directory..."
	@TRACE=$(TRACE) ./scripts/verify-directory-files.sh -d $(TOOLS_DIR) go.tool.mod go.tool.sum README.md

.PHONY: verify-shellcheck
verify-shellcheck: ## Verify shell files
	@echo "Verifying shell files..."
	@TRACE=$(TRACE) ./scripts/verify-shellcheck.sh $(SHELLCHECK_VER)

.PHONY: verify-trailing-newline
verify-trailing-newline: ## Verify all files end with a newline
	@echo "Verifying all files end with a newline..."
	@TRACE=$(TRACE) ./scripts/verify-trailing-newline.sh

APIDIFF_OLD_COMMIT ?= $(shell git rev-parse origin/main)

.PHONY: apidiff
apidiff:  ## Check for API differences
	@echo "Checking for API differences..."
	@$(GO_APIDIFF) $(APIDIFF_OLD_COMMIT) --print-compatible

## --------------------------------------
## Testing
## --------------------------------------

##@ test:

ARTIFACTS ?= ${ROOT_DIR}/_artifacts

KUBEBUILDER_ASSETS ?= $(shell $(SETUP_ENVTEST) use -p path $(KUBEBUILDER_ENVTEST_KUBERNETES_VERSION) --index https://raw.githubusercontent.com/openshift/api/master/envtest-releases.yaml)

.PHONY: setup-envtest
setup-envtest: ## Set up envtest (download kubebuilder assets)
	@echo "Setting up envtest (download kubebuilder assets)..."
	@echo "KUBEBUILDER_ASSETS=$(KUBEBUILDER_ASSETS)"

.PHONY: test
test: ## Run unit and integration tests with race detector
	KUBEBUILDER_ASSETS="$(KUBEBUILDER_ASSETS)" go test -race ./... $(TEST_ARGS)

.PHONY: $(GINKGO_BIN)
$(GINKGO_BIN): $(GINKGO) ## Build a local copy of ginkgo.

$(GINKGO): # Build ginkgo from bin dir.
	GOBIN=$(BIN_DIR) $(GO_INSTALL) $(GINKGO_PKG) $(GINKGO_BIN) $(GINKGO_VER)
