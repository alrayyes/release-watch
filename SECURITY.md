# Security

## Reporting a vulnerability

Please report it privately, through
[GitHub's private vulnerability reporting](https://github.com/alrayyes/release-watch/security/advisories/new)
— the Security tab of this repository, "Report a vulnerability". That opens a
draft advisory only you and the maintainers can see.

Not a public issue, please. This image is the container a scheduled job runs
inside, holding forge and registry tokens, so a working exploit posted in the
open is a working exploit against every pipeline using it.

Tell me what you did, what happened, and what you expected. A `Dockerfile` or a
workflow that reproduces it is worth more than a description of one.

I acknowledge within a week and tell you what I think, whether or not I
agree it is a vulnerability. If it is one, the fix ships as a `fix:` commit and
the advisory is published with the release that carries it.

## Supported versions

The latest release, and only the latest. Every fix cuts a new tag and a new
image, so "upgrade" is the patch. Pinned digests do not update themselves —
that is what pinning means — so a pin is a decision to stay on that image until
something moves it.

## What this image is exposed to

Worth knowing before you go looking, because these are deliberate:

- **It runs as UID 1000, not root.** `$HOME` is `/home/watch`. A process that
  starts non-root begins with zero Linux capabilities, so privilege
  escalation inside the container needs a kernel bug even before anything
  drops capabilities at runtime.
- **`tea` and `bun` are not from apk.** `tea` is the upstream release binary, checked
  against an SHA-256 in the `Dockerfile`. `bun` is copied from the official image,
  pinned by digest. Dependabot cannot see the `tea` pin, so it is bumped by hand.
- **Alpine package versions are not pinned.** The base image digest is, and it
  is what a rebuild reproduces; the packages come from the Alpine branch that
  base was built on. The reasoning is in `.hadolint.yaml`. The practical effect
  is that a rebuild picks up Alpine's patches, and an unchanged digest does not.
- **No secret belongs in this image.** It ships no configuration. Tokens arrive
  at runtime from the job.

## Verifying what you pulled

Every release is attested:

```sh
gh attestation verify oci://ghcr.io/alrayyes/release-watch:latest --repo alrayyes/release-watch
```

That tells you which commit and which workflow run built the digest. An image
that fails it did not come from here.
