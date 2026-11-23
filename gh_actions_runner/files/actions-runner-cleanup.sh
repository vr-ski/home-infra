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

main_cleanup() {
    # Directories to remove after every completed job.
    CLEANUP_DIRS=(
        "${RUNNER_WORK:-}"
        "${EXTRA_CLEANUP_DIRS[@]:-}"
    )

    for dir in "${CLEANUP_DIRS[@]}"; do
        [[ -n "${dir}" ]] || continue

        if [[ -d "${dir}" && ! -L "${dir}" ]]; then
            echo "Cleaning: ${dir}"

            find "${dir}" -mindepth 1 -maxdepth 1 \
                -exec rm -rf -- {} + ||
                echo "WARNING: Failed to completely clean ${dir}"
        fi
    done
}

cleanup_old_runner_versions() {
    local component link current_target current_name path name

    for component in bin externals; do
        link="${RUNNER_DIR}/$component"

        # Only clean up when the active component is a valid symlink.
        [[ -L "${link}" ]] || continue

        current_target=$(readlink -f -- "${link}") || continue
        [[ -d "${current_target}" ]] || continue

        # Only accept targets directly inside RUNNER_DIR.
        [[ "${current_target%/*}" == "${RUNNER_DIR}" ]] || continue

        current_name="${current_target##*/}"

        for path in "${RUNNER_DIR}/$component".*; do
            [[ -d "${path}" && ! -L "${path}" ]] || continue

            name="${path##*/}"

            # Match versioned directories only.
            [[ "${name}" =~ ^${component}\.[0-9]+(\.[0-9]+)*$ ]] || continue

            # Never remove the currently active version.
            [[ "${name}" == "${current_name}" ]] && continue

            echo "Removing old runner version: ${path}"
            rm -rf -- "${path}" ||
                echo "WARNING: Failed to remove ${path}"
        done
    done

    # Remove runner installation archives.
    for path in "${RUNNER_DIR}"/actions-runner-linux-x64-*.tar.gz; do
        [[ -f "${path}" ]] || continue
        [[ "${path}" =~ -[0-9]+(\.[0-9]+)+\.tar\.gz$ ]] || continue

        echo "Removing old runner archive: ${path}"
        rm -f -- "${path}" ||
            echo "WARNING: Failed to remove ${path}"
    done
}

main_cleanup
#cleanup_old_runner_versions

exit 0
