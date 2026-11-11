# Home Assistant on FreeBSD (iocage jail)

Ansible playbooks to provision, configure, and update Home Assistant Core
in an iocage jail on FreeBSD. Home Assistant runs from a Python virtual
environment (`--system-site-packages`) so that heavy native packages are
satisfied by FreeBSD `pkg` rather than compiled from source.

## Requirements

- FreeBSD host with `iocage` installed and a `bridge0` network for VNET jails
- Ansible control node with SSH key access to the host as `root`
- The target jail must exist before running playbooks 02 onward

## Layout

```
inventory/
└── group_vars/
    └── iocage_hosts.yml            # jail_name, paths, users, package lists
playbooks/
├── 01_create_jail.yml              # create and configure the jail
├── 02_install_homeassistant.yml    # pkg, venv, HA, HACS
├── 03_copy_config.yml              # copy .homeassistant from an old install
└── 04_update_homeassistant.yml     # snapshot, upgrade, verify
```

## Variables

All variables live in `inventory/group_vars/iocage_hosts.yml` and are loaded
automatically for the `iocage_hosts` group. Playbooks do not use
`vars_files`. Key paths:

| Variable | Default | Purpose |
|----------|---------|---------|
| `jail_name` | `home` | iocage jail name |
| `homeassistant_data` | `/home/homeassistant` | config, PID, database |
| `homeassistant_venv` | `/srv/homeassistant` | virtualenv (pip, hass) |

## Usage

Run from this directory. `ansible.cfg` supplies the inventory path.

```bash
# Provision
ansible-playbook playbooks/01_create_jail.yml
ansible-playbook playbooks/02_install_homeassistant.yml

# Migrate an existing installation
ansible-playbook playbooks/03_copy_config.yml

# Update an existing installation
ansible-playbook playbooks/04_update_homeassistant.yml
```

Override any variable for a single run with `-e`:

```bash
ansible-playbook playbooks/04_update_homeassistant.yml -e jail_name=ha_staging
```

## Updates and rollback

`04_update_homeassistant.yml` creates an iocage snapshot named
`pre-ha-update-<version>-<timestamp>` before stopping the service. If the
upgrade fails, the snapshot name is printed in the playbook output and in the
`iocage snaplist <jail>` output. Restore with:

```bash
iocage rollback <jail>@pre-ha-update-<version>-<timestamp>
iocage start <jail>
```

The snapshot captures the entire jail — venv, config, and database — so a
rollback returns the system to its exact pre-update state.

## FreeBSD notes

- `02_install_homeassistant.yml` installs `python3XX`, `py3XX-wheel`,
  `py3XX-setuptools`, `py3XX-installer`, `py3XX-packaging`, `py3XX-sqlite3`,
  `py3XX-tomli`, `jpeg-turbo`, `png`, `cmake`, `gmake`, `nasm`, `git-tiny`,
  `rust`, `ffmpeg-nox11` and `pkgconf` via `pkg` before creating the venv. 
  Without these, `pip` attempts to compile them from source and fails.
- The venv is created with `--system-site-packages` so it can see those
  system packages. This trades isolation for build reliability.
- The service runs via `/usr/sbin/daemon` from an rc script. `rc.subr`
  handles the user switch; `daemon` does not use `-u`. See
  `/usr/local/etc/rc.d/homeassistant` inside the jail.
