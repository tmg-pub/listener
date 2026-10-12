#!/bin/sh
# Stamps Listener.toc's "## Version:" line with the current git version
# (nearest tag, or the short commit hash if there's no tag yet) every time
# the working tree changes. This is the local, no-CI substitute for the
# "@@addon_version@@" token that the CurseForge forgepush pipeline fills in
# on tagged releases -- that token is left untouched in the committed TOC
# so forgepush still works, this just patches the *working copy* so a git
# checkout of this repo shows a real version in-game without needing a
# release build.
#
# Installed via `git config core.hooksPath .githooks` and called from the
# post-checkout / post-merge hooks in this same directory.

set -eu

root="$(git rev-parse --show-toplevel)"
cd "$root"

toc="addon/Listener.toc"
[ -f "$toc" ] || exit 0

version="$(git describe --tags --always --dirty 2>/dev/null || true)"
[ -n "$version" ] || exit 0

current="$(grep -m1 '^## Version:' "$toc" || true)"
new="## Version: $version"
[ "$current" = "$new" ] && exit 0

sed -i "s/^## Version:.*/## Version: $version/" "$toc"

# Tell git to stop reporting this file as modified -- the substitution is a
# local build artifact, not something that should show up in `git status`
# or get committed.
git update-index --skip-worktree "$toc" 2>/dev/null || true

echo "Listener: stamped $toc -> $version"
