# Agent Instructions

This repository contains shared utilities and packages for controller-runtime based projects at OpenShift.

## Development Commands

```bash
make help              # Show all available targets
make lint              # Run golangci-lint
make test              # Run tests with race detector
make verify            # Run all verification checks
```

## Key Constraints

1. **Avoid circular dependencies** - This is the top priority
2. **Minimize external dependencies** - Especially avoid conflicts with controller-runtime

## Writing Go Code

- Use Ginkgo/Gomega for tests
- Follow `.golangci.yaml`

