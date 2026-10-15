# release-watch

[![CI](https://github.com/alrayyes/release-watch/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/alrayyes/release-watch/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/alrayyes/release-watch?sort=semver)](https://github.com/alrayyes/release-watch/releases/latest)
[![image](https://img.shields.io/badge/ghcr.io-release--watch-2496ED?logo=docker&logoColor=white)](https://github.com/alrayyes/release-watch/pkgs/container/release-watch)
[![licence](https://img.shields.io/badge/licence-GPL--3.0--or--later-blue)](LICENSE)

An Alpine image carrying the tools a scheduled release-watch job needs, so the
job stops installing them on every run.

```text
ghcr.io/alrayyes/release-watch:latest
```

A release watcher polls GitHub for a new release, reads the image digest from
ghcr.io, then branches, commits, opens a pull request on a Forgejo instance and
merges it once CI is green. That takes a handful of command-line tools that no stock
runner image has together. This image is that toolbox and nothing else.

## Requirements

A container runtime that can pull from `ghcr.io`. The package is public, so no
registry credentials. The image is `linux/amd64` only.

## What's in it

| Tool                     | Why                                                                                                                    |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| `bash`, `jq`             | the watcher script is bash and parses forge JSON with `jq`                                                             |
| `git`, `ca-certificates` | clone, branch and push over HTTPS with the system CA store                                                             |
| `nodejs`                 | `actions/checkout` **is** a node program. Without it the step never starts: exec `node` not found, exit 127            |
| `curl`                   | reads the public GitHub API with no login                                                                              |
| `gh`                     | reads a repository's latest release                                                                                    |
| `skopeo`                 | reads an image digest from a registry. A runner job has no docker daemon, so `docker buildx` is not an option          |
| `tea`                    | the Forgejo command-line client: opens, lists, comments on and merges pull requests. The upstream binary, not Alpine's |
| `bun`                    | runs the watched repository's own lint hook                                                                            |

It has no entrypoint and runs nothing. It is somewhere for a CI job to stand.

## Configuration

It runs as a non-root user (`1000:1000`, `HOME=/home/watch`) and ships no
configuration. Tokens for GitHub and the forge arrive as environment variables or
logins set up by the job.

## Using it

```yaml
jobs:
  watch:
    runs-on: docker
    container:
      image: ghcr.io/alrayyes/release-watch:<version>@sha256:<digest>
    steps:
      - uses: actions/checkout@v5
      - run: scripts/auto-release-watch.sh --once
```

Pin the version **and** the digest. The version makes a bump readable in review;
the digest is what runs.

Verify where an image came from:

```sh
gh attestation verify oci://ghcr.io/alrayyes/release-watch:latest --repo alrayyes/release-watch
```

## Releasing

Nobody picks a version. release-please reads the Conventional Commits that land
on `main` and keeps a release pull request open. Merging it tags the release,
and the same run builds the image, pushes it and attests it. Tags are bare
semver, `1.3.0` and not `v1.3.0`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security reports go through
[SECURITY.md](SECURITY.md), not the issue tracker.

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE).
