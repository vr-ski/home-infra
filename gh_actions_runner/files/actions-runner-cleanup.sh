#!/usr/bin/env bash
#
# GitHub Actions runner: cleanup after each job.
# Configurable through /etc/actions-runner-cleanup.conf
#

set -uo pipefail

CONFIG_FILE="/etc/actions-runner-cleanup.conf"

if [[ -r "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Directories to remove after every completed job.
CLEANUP_DIRS=(
    "${RUNNER_WORK[@]:-}"
    "${EXTRA_CLEANUP_DIRS[@]:-}"
)

for dir in "${CLEANUP_DIRS[@]}"; do
    [[ -n "$dir" ]] || continue

    if [[ -d "$dir" && ! -L "$dir" ]]; then
        echo "Cleaning: $dir"

        find "$dir" -mindepth 1 -maxdepth 1 \
            -exec rm -rf -- {} + ||
            echo "WARNING: Failed to completely clean $dir"
    fi
done

exit 0
