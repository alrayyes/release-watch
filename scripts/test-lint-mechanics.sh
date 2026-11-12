#!/usr/bin/env bash
# lint-mechanics.sh checks the whole tree when run bare (CI), and only the
# Markdown it is given when the pre-push hook passes the pushed files, so a push
# that changed one document doesn't start a JVM over all of them. A fake
# ltex-cli-plus records what it was handed. The hook's glob is checked
# statically.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

failed=0
fail() {
  echo "FAIL: $1"
  failed=1
}

# The version comes from the script, so a bump there can't leave this testing a
# path nothing uses.
script="${SCRIPT:-$root/scripts/lint-mechanics.sh}"
version=$(sed -n 's/^VERSION=//p' "$script")
[ -n "$version" ] || {
  echo "FAIL: no VERSION= in $script"
  exit 1
}

# The script looks for the real binary under a cache; point it at a fake one,
# and keep HOME and XDG_CACHE_HOME in the temp dir so the real cache is untouched.
export HOME="$tmp/home"
export XDG_CACHE_HOME="$tmp/cache"
bindir="$XDG_CACHE_HOME/ltex-ls-plus/$version/ltex-ls-plus-$version/bin"
mkdir -p "$HOME" "$bindir" \
  "$XDG_CACHE_HOME/ltex-ls-plus/$version/ltex-ls-plus-$version/jdk-21" \
  "$tmp/repo/scripts"
cat >"$bindir/ltex-cli-plus" <<FAKE
#!/usr/bin/env bash
printf '%s\n' "\$@" | grep -v '^--' >"$tmp/seen"
FAKE
chmod +x "$bindir/ltex-cli-plus"
cp "$script" "$tmp/repo/scripts/lint-mechanics.sh"

cd "$tmp/repo"
git init -q
echo '{}' >.ltex.json
for f in README.md docs.md CHANGELOG.md CODE_OF_CONDUCT.md .claude/x.md openspec/changes/x.md openspec/specs/y.md; do
  mkdir -p "$(dirname "$f")"
  echo hi >"$f"
done
echo hi >docs.md.bak
git add -A

# run [args…]: what the fake ltex saw, space-joined and sorted.
run() {
  rm -f "$tmp/seen"
  set +e
  scripts/lint-mechanics.sh "$@" >/dev/null 2>&1
  echo "$?" >"$tmp/status"
  set -e
  if [ -f "$tmp/seen" ]; then LC_ALL=C sort "$tmp/seen" | tr '\n' ' '; else echo none; fi
}

all="README.md docs.md "
[ "$(run)" = "$all" ] || fail "bare run is not the whole tree minus exclusions: $(run)"
[ "$(run docs.md)" = "docs.md " ] || fail "a pushed file is not the only one checked: $(run docs.md)"
[ "$(run docs.md src/main.go)" = "docs.md " ] || fail "a non-Markdown file reached ltex: $(run docs.md src/main.go)"
[ "$(run CHANGELOG.md CODE_OF_CONDUCT.md .claude/x.md openspec/changes/x.md openspec/specs/y.md)" = "none" ] || fail "excluded files were checked"
[ "$(run README.md docs.md)" = "README.md docs.md " ] || fail "only one of two pushed files was checked: $(run README.md docs.md)"
[ "$(run docs.md.bak)" = "none" ] || fail "a file that merely contains a Markdown name was checked"
run CHANGELOG.md >/dev/null
[ "$(cat "$tmp/status")" = 0 ] || fail "a push with no prose must exit 0"
[ "$(run README.md .ltex.json)" = "$all" ] || fail "Markdown plus .ltex.json did not check the whole tree: $(run README.md .ltex.json)"
[ "$(run docs.md scripts/lint-mechanics.sh)" = "$all" ] || fail "Markdown plus the script did not check the whole tree"
[ "$(run .ltex.json)" = "$all" ] || fail "a config-only push did not check the whole tree: $(run .ltex.json)"
[ "$(run scripts/lint-mechanics.sh)" = "$all" ] || fail "a script-only push did not check the whole tree"

cd "$root"
job=$(awk '/^    - name: mechanics$/{p=1;print;next} /^    - (name|run):/{p=0} p' lefthook.yml)
grep -q 'glob:' <<<"$job" || fail "the mechanics hook has no glob, so every push starts a JVM"
grep -Fq '{push_files}' <<<"$job" || fail "the mechanics hook does not pass the pushed files"
grep -Fq '.ltex.json' <<<"$job" || fail "the mechanics hook ignores a change to .ltex.json"
grep -Fq 'lint-mechanics.sh' <<<"$job" || fail "the mechanics hook does not run lint-mechanics.sh"

exit "$failed"
