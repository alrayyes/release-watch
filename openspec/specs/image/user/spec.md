# image/user Specification

## Purpose
Stops a compromised job starting with root inside the container. A non-root
process begins with zero Linux capabilities, so privilege escalation needs a
kernel bug even before anything drops capabilities at runtime.

## Requirements

### Requirement: Image runs as a non-root user
The published image SHALL run its default process as a non-root user with a
numeric UID and GID, and SHALL set `HOME` to that user's home directory so
shell `~` expansion resolves without depending on `/etc/passwd` lookups.

#### Scenario: Default process identity
- **WHEN** the image runs with no overriding `--user` flag
- **THEN** `id` reports a non-zero UID and GID

#### Scenario: HOME resolves for shell expansion
- **WHEN** the image runs and a shell expands `$HOME` or `~`
- **THEN** it resolves to `/home/watch`, not `/root`
