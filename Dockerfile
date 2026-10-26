FROM oven/bun:1.4.4-alpine@sha256:4cf82f5686b196504fe119db3fcd9185b191f82ece82c40680e597228ec6070a AS bun

FROM alpine:3.24.3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

# What a release-watching job needs, in the image rather than installed on every run.
# It is the toolbox scripts/auto-release-watch.sh in homelab/vps-docker stands in:
#
#   bash, jq                the script is bash and parses forge JSON with jq
#   git, ca-certificates    clone, branch and push over HTTPS with the system CA store
#   nodejs                  actions/checkout is a node program whichever way it fetches;
#                           without it the step never starts, exit 127
#   curl                    reads the public GitHub API with no login, and is what the
#                           hush-hush action downloads its CLI with
#   github-cli              `gh api` reads the latest release of the watched repo
#   skopeo                  `skopeo inspect` reads an image digest from ghcr.io. A runner
#                           job has no docker daemon, so `docker buildx imagetools` is out
#   tea                     the Forgejo CLI, below
#   bun                     the target repo's lint hook runs `bun run lint`
#
# The apk packages are deliberately unpinned, for the reason .hadolint.yaml gives: a
# version belongs to the Alpine branch, not this file.
RUN apk --no-cache add \
        bash \
        ca-certificates \
        curl \
        git \
        github-cli \
        jq \
        nodejs \
        skopeo && \
    addgroup -g 1000 watch && \
    adduser -D -u 1000 -G watch -h /home/watch watch

# tea comes from the upstream release rather than apk. Alpine 3.24 ships 0.9.2, which
# predates `tea api` and the JSON output the script relies on. The binary is static, so
# musl is no obstacle. Dependabot cannot see this pin: bump it by hand and update the
# checksum from https://dl.gitea.com/tea/<version>/tea-<version>-linux-amd64.sha256.
ARG TEA_VERSION=0.16.0
ARG TEA_SHA256=9c142c8a0b31485eea2387031c1c404f12b7141075eb4ffbd7ced49441590636
ADD --checksum=sha256:${TEA_SHA256} --chmod=0755 https://dl.gitea.com/tea/${TEA_VERSION}/tea-${TEA_VERSION}-linux-amd64 /usr/local/bin/tea

# bun is copied from the official image, pinned by digest above. The Alpine variant is
# musl, like this image, so the binary runs as is.
COPY --from=bun /usr/local/bin/bun /usr/local/bin/bun

# HOME is set explicitly: Docker does not export it just because USER names an entry
# with a home directory.
ENV HOME=/home/watch
USER 1000:1000
