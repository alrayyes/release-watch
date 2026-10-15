# Contributing

## What you need

- **bun** `1.3.14`, pinned in `.bun-version`. It installs the dev dependencies
  and runs the hooks; there is no node in this repo any more.
- **Docker**, to build the image and to run hadolint.

That is the whole toolchain. Everything else arrives through `bun install`.

## Getting set up

```sh
bun install
```

That installs the dependencies and, through the `prepare` script, installs
lefthook's git hooks. Do it before your first commit — the hooks are most of
what stops CI being the place you find things out.

## The checks

Run what the pipeline runs:

```sh
bun run lint                # biome: JSON, and anything else it supports
bun run lint:pkg            # sort-package-json: canonical key order
bun run check:biome-schema  # biome.json's $schema vs. the pinned @biomejs/biome
bun run audit               # bun audit: known vulnerabilities in pinned deps, all of them
bun run format:check        # prettier: Markdown and YAML layout
bun run lint:md             # markdownlint: structure, links, heading levels
bun run lint:mechanics      # ltex: grammar and spelling
bun run lint:prose          # vale: house style

docker run --rm -i -v "$PWD/.hadolint.yaml:/.hadolint.yaml:ro" hadolint/hadolint:v2.15.1-alpine@sha256:a1d49ae1a4e83c1dbad26b8c1ad7588c8bd1e04f4866b34ad3cac50335198552 hadolint --config /.hadolint.yaml - < Dockerfile
docker build .
```

Prose is linted in tiers because they answer to different things. Layout is
Prettier's, structure is markdownlint's, mechanics have a right answer, and
style is advice. Mechanics fails the build; style reports and does not, because
style advice that blocks a merge teaches people to skip the hooks.

`bun run format`, `bun run lint:fix` and `bun run lint:pkg:fix` are the
writing versions of `format:check`, `lint` and `lint:pkg`. They take file
arguments (`bun run format README.md`), which is how the hook calls them.

The hooks run the same commands, which is the point — they cannot drift from CI
if there is one copy of each:

- **pre-commit** judges only what the commit contains: every job is handed the
  staged files, so a half-finished file elsewhere can't fail or be rewritten by
  a commit. It formats them with biome and Prettier and restages what they
  touched, then runs markdownlint, and hadolint on a staged `Dockerfile` (read
  from the index). It may write, and it never builds the image.
- **commit-msg** runs commitlint.
- **pre-push** runs everything in check mode over the whole tree, including the
  two prose tiers. It never writes: a hook rewriting files under a push leaves
  the pushed commit and your working tree disagreeing about what was reviewed.

The first `bun run lint:mechanics` downloads ltex-ls-plus, which is about
300 MB because it ships its own JVM. It caches outside the repository under
`$XDG_CACHE_HOME`, so that is once per machine and a few seconds thereafter.
Vale fetches its style packages into `styles/` on first run; both of those
directories are gitignored.

CI adds one check the hooks cannot: it runs the built image and asserts that
`bash`, `git`, `node`, `jq`, `gh`, `skopeo`, `tea` and `bun` all resolve and that
it does not run as root. If Alpine renames or drops a package, `apk add` still
succeeds for the rest and the build stays green. The failure would otherwise turn
up in a scheduled job somewhere else.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/), enforced by
commitlint on `@commitlint/config-conventional` unextended. The format is not
decoration: release-please reads it to decide the next version, so a commit that
does not parse gets no changelog entry and moves no version.

- `fix:` takes the patch, `feat:` the minor, a `BREAKING CHANGE:` footer the
  major.
- `chore:` and `docs:` release nothing. That is deliberate for tooling — bumping
  biome should not republish a byte-identical container — and it is why a base
  image bump is configured to raise `fix(deps):` instead.

One logical change per commit, each building and passing its own tests. A
refactor and a feature are two commits.

## Changing the Dockerfile

Two things there are load-bearing, and both have their reasoning written beside
them:

- **Alpine package versions are deliberately unpinned**, and hadolint's DL3018
  is turned off in `.hadolint.yaml` to allow it. An apk version belongs to the
  Alpine branch the base image is built on rather than to this file, and Alpine
  keeps one build per branch and prunes the rest — so there is no version list
  to read and no archive to pin against. Read that file in full before adding
  another package.
- **`tea` is the upstream release binary**, pinned by version and SHA-256 build
  arguments, because Alpine's package predates `tea api`. Dependabot cannot see
  it. Bump both arguments together.
- **The base image digest is pinned**, and that is the part that is genuinely
  reproducible. It moves only when someone bumps it by hand and opens a pull
  request.

Adding a package makes the image bigger for everyone pulling it, so it wants an
argument in the commit message, not just a line in the `RUN`.

## Tracking a change

A non-trivial change carries two records, side by side: a GitHub issue for
why it matters, and an OpenSpec change under `openspec/changes/` for
_what the system must do_ — a proposal, a spec delta where behaviour
actually changes, and a task list. Neither replaces the other. Create one
with `openspec new change <name>`, or ask your assistant to propose one;
`openspec archive <name>` folds a finished change's spec deltas into
`openspec/specs/` once it ships. A pure tooling, config or docs change with
no observable behaviour change sets `skip_specs: true` in the change's
`.openspec.yaml` rather than inventing a spec for it.

`openspec/` and `.claude/` (OpenSpec's own generated skills and commands)
are excluded from this repo's Markdown linting: they follow OpenSpec's own
template contract, not this repo's house style.

## Opening a pull request

Branch, push, open a pull request — nothing lands on `main` directly. Read your
own diff first; if it carries two changes, say so at the top of the description
rather than leaving it to be found.

Label it from GitHub's standard set (`bug`, `enhancement`, `documentation`, …).

Spend the description on **why**. The diff already says what.

**Pull requests are squash merged**, and it is the only method this repository
allows. That is release-please's documented workflow: one pull request becomes
one commit on `main`, and the changelog entry is that commit.

Merge commits were the alternative and they doubled every changelog entry.
GitHub builds the body of a merge commit from the pull request title, so a
branch carrying its own `fix(ci): ...` commit and the merge commit landing it on
`main` both parse as conventional commits, and release-please counted them
twice. No setting
avoids it — GitHub permits only three title/body combinations for merge
commits, and each leaves the conventional subject somewhere release-please
reads.

The cost is that a branch built as a readable sequence of commits collapses to
one, so **the pull request title and body become the commit message**. Write
them accordingly.

## Releasing

You do not. release-please keeps a release pull request open against `main`
carrying the next version and the changelog entry; merging it tags the release,
and the same run builds the image, pushes it to `ghcr.io` and attests its
provenance.

It is one workflow rather than two because a tag pushed with `GITHUB_TOKEN`
starts no further workflow run — a separate on-tag workflow would silently never
fire, and the first symptom is a release with no image against it.
