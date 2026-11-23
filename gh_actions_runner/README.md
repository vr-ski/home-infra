# GitHub Actions Runner (self-hosted)

Ansible playbooks to maintain a self-hosted GitHub Actions runner on Linux. The setup provides manual cleanup of configured directories and files, as well as automatic cleanup after every completed job using the GitHub Actions runner hook.

## Requirements

- Linux host with a self-hosted GitHub Actions runner installed as a systemd service
- Ansible control node with SSH access to the runner
- SSH user with sudo privileges on the target host
- Runner installed under `/home/runner/actions-runner` (adjust variables if different)
- `sudo` installed on the managed runner host.
- The SSH user must have permission to execute commands as root through `sudo`. Either:
  - Configure passwordless sudo for the user, or
  - Provide the user's sudo password when running Ansible with `--ask-become-pass` (`-K`).



## Layout

```text
inventory.example                   # copy to intentory and set the runner host and user

playbooks/
├── 01_gh_runner_cleanup.yml        # delete configured paths
└── 02_deploy_hook.yml              # deploy and configure post-job cleanup hook

files/
├── actions-runner-cleanup.sh       # cleanup script executed after each job
└── actions-runner-cleanup.conf     # additional cleanup directories

vars/
└── runner-cleanup.yml              # runner settings and cleanup paths
```

## Variables

All Ansible variables live in `vars/runner-cleanup.yml`.

| Variable | Default | Purpose |
|----------|---------|---------|
| `runner_user` | `runner` | Runner service account |
| `runner_group` | `runner` | Runner service group |
| `runner_dir` | `/home/runner/actions-runner` | Runner installation directory |
| `runner_service` | `actions.runner.YOUR_SERVICE_NAME.service` | systemd service name |
| `cleanup_paths` | See configuration | Explicit list of paths deleted by the Ansible cleanup playbook |

### Post-job cleanup

`files/actions-runner-cleanup.conf` defines additional directories to remove after each completed job.

```bash
EXTRA_CLEANUP_DIRS=(
    "/var/cache/waterfox-builder/waterfox-src"
)
```

The cleanup script always cleans the runner workspace (`_work`) and additionally removes directories specified in `EXTRA_CLEANUP_DIRS`.

The Ansible cleanup playbook and post-job cleanup hook have independent cleanup configurations.

## Usage

Run from this directory.

```bash
# Clean configured paths
ansible-playbook -i inventory playbooks/01_gh_runner_cleanup.yml

# Deploy and configure post-job cleanup hook
ansible-playbook -i inventory playbooks/02_deploy_hook.yml
```

Target a specific runner:

```bash
ansible-playbook -i inventory playbooks/01_gh_runner_cleanup.yml --limit waterfox-runner
```

Override any variable for a single run with `-e`:

```bash
ansible-playbook -i inventory playbooks/01_gh_runner_cleanup.yml -e 'cleanup_paths=["/tmp/build-cache"]'
```

Prompt for sudo password with `-K`:
```bash
ansible-playbook -i inventory playbooks/02_deploy_hook.yml -K
```

Debug step by step (press `y` to go to the next step):

```bash
ansible-playbook -i inventory playbooks/02_deploy_hook.yml --step
```

## Post-job cleanup

The deployment playbook installs the cleanup script and configuration, then configures the runner's `.env` file with:

```ini
ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/usr/local/bin/actions-runner-cleanup.sh
```

The runner executes this script synchronously after each completed job.

The script:

- Removes the contents of the runner workspace (`_work`).
- Removes additional directories specified in `EXTRA_CLEANUP_DIRS`.
- Does not remove the runner installation or other unspecified paths.
- Returns exit code `0` to avoid failing a workflow because of cleanup errors.

The runner service is restarted when deployment changes are detected.

## Notes

- `01_gh_runner_cleanup.yml` removes the configured paths themselves, including their contents.
- The post-job cleanup script removes the contents of `_work`, preserving the workspace root directory.
- Additional cleanup directories are removed entirely.
- The runner account must have sufficient permissions to delete the configured paths.
- The Ansible cleanup playbook should only be executed when the runner is idle.
- The deployment playbook's test task executes the actual cleanup script, so it performs real deletion.
- Runner installation files, versioned `bin.*` and `externals.*` directories, and diagnostic logs are not touched by these cleanup mechanisms.

