# Tools Directory

This directory contains the Go tool dependency management files for this repository.

## Purpose

The `tools/` directory is used to manage developer tooling dependencies separately from the main application dependencies. This is done using Go 1.24+ tool dependency management with a separate `go.tool.mod` file.

## Files

This directory should **only** contain the following files:

- `go.tool.mod` - The Go module file defining tool dependencies
- `go.tool.sum` - The checksum file for tool dependencies
- `README.md` - This documentation file

## What Must Be Done

✅ **DO**:
- Keep `go.tool.mod` and `go.tool.sum` up to date
- Run `go mod tidy` from inside this directory to ensure dependencies are tidy
- Use `go get -tool -modfile=tools/go.tool.mod <tool>@<version>` to add/update tools
- Use `go tool -modfile=tools/go.tool.mod <tool>` to run tools

## What Must NOT Be Done

❌ **DON'T**:
- Add any other files except the three allowed files listed above
- Modify `go.tool.mod` manually - use `go get -tool` commands instead

## Adding or Updating Tools

To add a new tool:

```bash
go get -tool -modfile=tools/go.tool.mod <tool-import-path>@<version>
```

To update a tool to the latest version:

```bash
go get -tool -modfile=tools/go.tool.mod <tool-import-path>
```

To remove a tool:

```bash
go get -tool -modfile=tools/go.tool.mod <tool-import-path>@none
```

## Verification

The `make verify` target includes a check (`verify-tools-directory`) that ensures this directory only contains the allowed files. This check will fail if any disallowed files are present.

## References

- [Managing Tool Dependencies in Go 1.24+](https://www.alexedwards.net/blog/how-to-manage-tool-dependencies-in-go-1.24-plus)
