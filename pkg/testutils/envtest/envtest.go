/*
Copyright 2026 Red Hat, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// Package envtest provides utilities for working with the controller-runtime envtest package.
package envtest

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// GetGoModuleDirectory returns the directory path for a go module.
// It uses 'go list -m' to find the module directory, which will be in the
// module cache if the module is not vendored.
//
// Example:
//
//	moduleDir, err := GetGoModuleDirectory("github.com/openshift/api")
//	if err != nil {
//	    return err
//	}
func GetGoModuleDirectory(ctx context.Context, module string) (string, error) {
	cmd := exec.CommandContext(ctx, "go", "list", "-m", "-f", "{{.Dir}}", module)
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get module directory for %s: %w", module, err)
	}
	moduleDir := strings.TrimSpace(string(output))
	if moduleDir == "" {
		return "", fmt.Errorf("empty module directory returned for %s", module)
	}
	return moduleDir, nil
}

// GetCRDManifestsPath returns the full path to the CRD manifests directory within a go module.
// It combines GetGoModuleDirectory with the provided path segments.
//
// Example:
//
//	crdPath, err := GetCRDManifestsPath(ctx, "github.com/openshift/api", "config", "v1", "zz_generated.crd-manifests")
//	if err != nil {
//	    return err
//	}
func GetCRDManifestsPath(ctx context.Context, module string, pathSegments ...string) (string, error) {
	moduleDir, err := GetGoModuleDirectory(ctx, module)
	if err != nil {
		return "", err
	}

	path := filepath.Join(append([]string{moduleDir}, pathSegments...)...)
	if _, err := os.Stat(path); err != nil {
		return "", fmt.Errorf("path %s does not exist: %w", path, err)
	}

	return path, nil
}
