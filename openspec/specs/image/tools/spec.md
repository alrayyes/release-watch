# image/tools Specification

## Purpose
Gives a scheduled release-watch job every tool it calls, so the job installs
nothing at run time and a missing tool fails here instead of in a pipeline
somewhere else.

## Requirements

### Requirement: Image carries the release-watch toolbox
The published image SHALL provide `bash`, `curl`, `git`, `node`, `jq`, `gh`,
`skopeo`, `tea` and `bun` on `PATH`.

#### Scenario: Every tool resolves
- **WHEN** the built image runs `command -v` for each tool
- **THEN** each resolves, and CI fails the build if any does not

### Requirement: Tea is the upstream release, verified
The image SHALL install `tea` from the upstream release binary at a pinned
version, and SHALL fail the build if the binary's SHA-256 does not match the
pinned checksum. Alpine's `tea` package is not used because it predates
`tea api`.

#### Scenario: Checksum mismatch
- **WHEN** the downloaded binary does not match `TEA_SHA256`
- **THEN** the image build fails

#### Scenario: Subcommand needed by the watcher exists
- **WHEN** `tea api --help` runs in the image
- **THEN** it exits zero

### Requirement: Bun is copied from the pinned official image
The image SHALL take `bun` from the official `oven/bun` Alpine image, pinned by
digest, so the musl binary matches the base.

#### Scenario: Bun runs
- **WHEN** `bun --version` runs in the image
- **THEN** it exits zero
