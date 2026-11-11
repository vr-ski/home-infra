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
inventory.example                   # copy to intentory and set the freebsd host 
playbooks/
├── 01_create_jail.yml              # create and configure the jail
├── 02_install_homeassistant.yml    # delete existing venv, install pkg, venv, HA, HACS
├── 03_deploy_service.yml           # copy templates to jail
└── 04_update_homeassistant.yml     # snapshot, upgrade, verify
templates
├── rc.homeassistant.j2             # rc script file for freebsd service
└── run_hass.sh.j2                  # script to be used in the service
vars/
└── homeassistant.yml               # jail_name, paths, users, package lists
```

## Variables

All variables live in `vars/homeassistant.yml`.

| Variable | Default | Purpose |
|----------|---------|---------|
| `jail_name` | `home` | iocage jail name |
| `jail_release` | `15.1-RELEASE` | iocage jail release |
| `jail_interface` | `bridge0` | iocage jail network interface |
| `python_version` | `314` | python version for the jail and venv |
| `homeassistant_user` | `homeassistant` | username that will own the files and service |
| `homeassistant_group` | `homeassistant` | groupname that will own the files and service |
| `homeassistant_home` | `/home/homeassistant` | home directory of the homeassistant user|
| `homeassistant_venv` | `/srv/homeassistant` | virtualenv (pip, hass) |
| `homeassistant_config` | `{{ homeassistant_home }}/.homeassistant` | HA config path |
| `homeassistant_python` | `/usr/local/bin/python3.14` | python version that will create the venv |

## Usage

Run from this directory.

```bash
# Provision
ansible-playbook -i inventory playbooks/01_create_jail.yml
ansible-playbook -i inventory playbooks/02_install_homeassistant.yml

# Deploy service
ansible-playbook -i inventory playbooks/03_deploy_service.yml

# Update an existing installation
ansible-playbook -i inventory playbooks/04_update_homeassistant.yml
```

Override any variable for a single run with `-e`:

```bash
ansible-playbook -i inventory playbooks/04_update_homeassistant.yml -e jail_name=ha_staging
```

Debug step by step (press y to go to next step):
```bash
ansible-playbook -i inventory playbooks/04_update_homeassistant.yml --step
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

The snapshot captures the entire jail - venv, config, and database - so a
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
