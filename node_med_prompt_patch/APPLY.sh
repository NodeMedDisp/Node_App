#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=${1:-.}
mode=${2:-apply}
case "$mode" in apply|check) ;; *) echo "Usage: sh APPLY.sh [repo-path] [apply|check]" >&2; exit 1 ;; esac
root=$(git -C "$repo" rev-parse --show-toplevel)
cd "$root"
patch="$script_dir/app_medication_names_prompt_editing.patch"
expected_patch="57cfb3ea0db4ba6bb71efe86b5b99bcb945850ca67e2cf4039d155860ae079b8"
if command -v sha256sum >/dev/null 2>&1; then
    actual_patch=$(sha256sum "$patch" | cut -d ' ' -f 1)
else
    actual_patch=$(shasum -a 256 "$patch" | cut -d ' ' -f 1)
fi
[ "$actual_patch" = "$expected_patch" ] || { echo "Patch checksum mismatch; nothing applied." >&2; exit 1; }
[ -f pubspec.yaml ] || { echo "Expected Flutter app root; nothing applied." >&2; exit 1; }
if ! git diff --quiet --ignore-submodules || ! git diff --cached --quiet --ignore-submodules; then
    echo "Commit or stash tracked changes before applying. Nothing applied." >&2
    exit 1
fi
while IFS="$(printf '\t')" read -r expected path; do
    committed=$(git rev-parse "HEAD:$path")
    working=$(git hash-object "--path=$path" -- "$path")
    if [ "$committed" != "$expected" ] || [ "$working" != "$expected" ]; then
        echo "Baseline mismatch: $path. Nothing applied; do not force it." >&2
        exit 1
    fi
done < "$script_dir/PREIMAGES.tsv"
while IFS= read -r path; do
    if [ -e "$path" ]; then
        echo "New-file path already exists: $path. Nothing applied." >&2
        exit 1
    fi
done < "$script_dir/NEW_FILES.txt"
git apply --check "$patch"
if [ "$mode" = check ]; then
    echo "Checks passed. No files changed."
    exit 0
fi
git apply "$patch"
echo "Patch applied to Node_App. No commit or push was made. See TESTING.md."
