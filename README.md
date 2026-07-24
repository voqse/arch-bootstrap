# arch-install

Modular, config-driven Arch Linux installation script following the official
[Installation guide](https://wiki.archlinux.org/title/Installation_guide).

Written for installing my own machines. Defaults and presets reflect that
hardware; there is no promise of general-purpose use.

A host is described by a preset file: packages, services, kernel parameters,
disk layout. Presets inherit `config/default.conf` and optionally a role layer
(`desktop.conf` or `server.conf`), so a new machine is a short file of
overrides. Credentials (username, user password, root password) and timezone
are always collected interactively at the start of the run and never stored in
presets; hostname and swap parameters are prompted with the preset value as
the default.

The root filesystem is btrfs by default: subvolumes `@`, `@home`, `@log`,
`@pkg`, `@docker`, `@snapshots` (plus `@swap` when a swapfile is requested)
mounted with `noatime,compress=zstd`. snap-pac snapshots `@` around every
pacman transaction; caches, logs, Docker data, and the snapshots themselves
live outside `@` so rollback material stays small. Set `FILESYSTEM="ext4"`
in a preset for a plain ext4 root. The bootloader is always systemd-boot;
UEFI is required.

## Quick start

> Review scripts before piping them into a shell.

One-liner from the Arch ISO, defaults only — the script downloads the repo
into `/tmp/arch-install` and re-executes itself from there:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/voqse/arch-install/master/run.sh)
```

One-liner with a built-in preset from `config/`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/voqse/arch-install/master/run.sh) --preset matebook
```

Local clone with a custom preset:

```bash
git clone https://github.com/voqse/arch-install
cd arch-install
cp config/default.conf config/my.conf
# edit config/my.conf, then:
bash run.sh --config config/my.conf
```

The script prompts for anything not defined in the preset before touching the
disk and always asks for confirmation before partitioning. When finished:

```bash
umount -R /mnt
reboot
```

## Project structure

```
arch-install/
├── run.sh              # Entry point: argument parsing, interactive prompts
├── lib.sh                    # Shared helpers (logging, mkinitcpio editing)
│
├── config/
│   ├── default.conf          # Base preset — inherited by everything
│   ├── desktop.conf          # Role layer: graphical stack (greetd/niri/Wayland)
│   ├── server.conf           # Role layer: headless (sshd, docker.service)
│   ├── matebook.conf         # Huawei MateBook D16 2021 (Ryzen 4600H, desktop)
│   ├── chuwi.conf            # CHUWI UBox (Ryzen 6600H, desktop)
│   └── station.conf          # Workstation (5800X3D / RTX 4070 Ti, headless server)
│
├── modules/                  # Pre-chroot pipeline (runs on the live ISO)
│   ├── 01-pre-checks.sh      # Assert UEFI, internet, NTP
│   ├── 02-disk.sh            # Partition, format, mount (btrfs subvolumes, ESP umask=0077)
│   ├── 03-mirrors.sh         # Mirror selection: MIRRORS list or reflector
│   ├── 04-pacstrap.sh        # pacstrap into /mnt
│   ├── 05-fstab.sh           # genfstab
│   └── 06-chroot.sh          # Serialise config, enter arch-chroot
│
├── chroot/
│   ├── configure.sh          # Chroot entry point
│   └── modules/              # In-chroot configuration
│       ├── 01-timezone.sh    # Timezone + systemd-timesyncd
│       ├── 02-localization.sh# locale.gen, locale.conf, vconsole.conf
│       ├── 03-hostname.sh    # /etc/hostname, /etc/hosts
│       ├── 04-users.sh       # Root password, user account, sudoers
│       ├── 05-bootloader.sh  # systemd-boot install + entry (resume offset for swapfile)
│       ├── 06-services.sh    # systemctl enable for the SERVICES array
│       ├── 07-hooks.sh       # Per-package configuration scripts
│       ├── 08-sleep.sh       # Suspend-then-hibernate (HIBERNATE_DELAY)
│       ├── 09-initramfs.sh   # mkinitcpio -P (after all hooks)
│       ├── 10-yay.sh         # AUR helper (yay) + YAY_PACKAGES
│       └── 11-xdg.sh         # Disable xdg-user-dirs auto-creation
│
└── hooks/                    # Per-package configuration scripts
    ├── amdgpu.sh             # amdgpu into mkinitcpio MODULES (early KMS)
    ├── bluez.sh              # Enables bluetooth.service
    ├── docker.sh             # docker group; overlay2 pin in daemon.json; enables docker.socket
    ├── fwupd.sh              # Enables fwupd-refresh.timer
    ├── greetd.sh             # greetd config with autologin into niri-session
    ├── iwd.sh                # Sets iwd as the NetworkManager Wi-Fi backend
    ├── networkmanager.sh     # Enables NetworkManager
    ├── nvidia-open.sh        # nvidia modules into mkinitcpio MODULES (early KMS)
    ├── nvm.sh                # Sources init-nvm.sh from the user's shell profiles
    ├── pacman-contrib.sh     # paccache.timer + drop-in purging uninstalled packages' cache
    ├── plymouth.sh           # plymouth mkinitcpio hook, splash cmdline, bgrt theme
    ├── reflector.sh          # Persists REFLECTOR_ARGS to reflector.conf; enables reflector.timer
    ├── snapper.sh            # Snapper root config for snap-pac (timeline off); cleanup timer
    ├── swaylock.sh           # pam_gnome_keyring unlock on swaylock
    ├── tlp-pd.sh             # Enables tlp-pd.service
    ├── tlp-rdw.sh            # Enables NetworkManager-dispatcher.service
    └── tlp.sh                # Enables tlp.service
```

## Configuration

### Inheritance

`run.sh` always sources `config/default.conf` first, then the selected
preset. A preset opts into a role layer by sourcing it at the top:

```bash
# desktop host
source "${BASH_SOURCE[0]%/*}/desktop.conf"

# headless host
source "${BASH_SOURCE[0]%/*}/server.conf"
```

Arrays are extended with `+=` so defaults are preserved:

```bash
BASE_PACKAGES+=("amd-ucode")
PACKAGES+=("mesa:amdgpu" "vulkan-radeon")
KERNEL_PARAMS+=("nvidia_drm.modeset=1")
```

Role layers hold what a whole class of machines shares:

- `desktop.conf` — greetd + niri Wayland session, plymouth boot splash,
  portals, terminal, lock/idle tooling, browsers.
- `server.conf` — enables `sshd` and `docker.service` from first boot
  (desktops keep docker socket-activated and start sshd manually).

### Localization

| Variable     | Description                                        | Default                             |
|--------------|----------------------------------------------------|-------------------------------------|
| `LOCALES`    | Locales to uncomment in `locale.gen`               | `("en_US.UTF-8" "ru_RU.UTF-8")`     |
| `LANG`       | System-wide language                               | `en_US.UTF-8`                       |
| `KEYMAP`     | Console keymap (`vconsole.conf`)                   | `ruwin_alt_sh-UTF-8`                |
| `FONT`       | Console font (`vconsole.conf`)                     | `cyr-sun16`                         |
| `XKBLAYOUT`  | X11/Wayland layout exported to `vconsole.conf`     | `us,ru`                             |
| `XKBOPTIONS` | X11/Wayland options                                | `grp:caps_toggle,grp_led:caps,compose:ralt` |

Timezone is not a preset value — it is always chosen interactively.
`systemd-timesyncd` NTP is always enabled.

### Disk

| Variable     | Description                                                        | Default   |
|--------------|--------------------------------------------------------------------|-----------|
| `DISK`       | Device path, e.g. `/dev/nvme0n1`; empty = prompt                   | `""`      |
| `FILESYSTEM` | `btrfs` (subvolume layout) or `ext4`                               | `btrfs`   |
| `SWAP_TYPE`  | `file`, `partition`, `none`, or `""` = prompt                      | `""`      |
| `SWAP_SIZE`  | e.g. `16G`; required when `SWAP_TYPE` is `file` or `partition`     | `""`      |

Partition layout (GPT / UEFI only):

| # | Size                      | Type                 | Filesystem      |
|---|---------------------------|----------------------|-----------------|
| 1 | 1024 MiB                  | EFI System Partition | FAT32           |
| 2 | `SWAP_SIZE` (only when `SWAP_TYPE=partition`) | Linux swap | swap |
| 3 | remainder                 | Linux filesystem     | btrfs or ext4   |

The ESP is mounted with `umask=0077` so the systemd-boot random seed and
kernel images are not world-readable. With `SWAP_TYPE=file` the swapfile lives
in a dedicated `@swap` subvolume (NOCOW, no compression) — snapshots of `@`
stay possible — and the resume offset is written to the boot entry for
hibernation.

### Snapshots (btrfs)

snap-pac creates pre/post snapshots of `@` around every pacman transaction;
`hooks/snapper.sh` sets up the root config with timeline snapshots disabled
and `NUMBER_LIMIT=10` (roughly the last five updates), pruned by
`snapper-cleanup.timer`. A monthly `btrfs-scrub@-.timer` is enabled for
integrity checking; no balance or defrag automation on purpose. Snapshots
share the disk with the system — they are rollback material, not backups.
Rollback is deliberately manual: the boot entry pins `subvol=@`, so restoring
means replacing `@` from `/.snapshots` (e.g. from the live ISO) rather than a
`snapper rollback` default-subvolume switch.

### Mirrors

`REFLECTOR_ARGS` is the single source of truth, used twice: at install time by
`modules/03-mirrors.sh` to rank mirrors, and on the installed system by
`hooks/reflector.sh`, which writes the same arguments to
`/etc/xdg/reflector/reflector.conf` and enables `reflector.timer`. Setting a
`MIRRORS` array in a preset bypasses reflector entirely.

### Packages

```bash
BASE_PACKAGES=(       # Passed to pacstrap; extend per host with += ("amd-ucode" etc.)
    "base"
    "base-devel"
    "linux"
    "linux-firmware"
)

PACKAGES=(            # Everything else; entries may carry a configuration hook
    "networkmanager"          # hooks/networkmanager.sh runs automatically (same name)
    "mesa:amdgpu"             # explicit hook — runs hooks/amdgpu.sh after install
)
```

Any package entry can carry a configuration script from `hooks/`:

1. **Auto-detection** — if `hooks/<package-name>.sh` exists, it runs whenever
   that package appears in `PACKAGES`.
2. **Explicit name** — `"package:hook-name"` runs `hooks/<hook-name>.sh`.

Hooks execute inside `arch-chroot` after all packages are installed, so the
full system toolset (`systemctl`, the serialised config in `config.sh`) is
available. `mkinitcpio -P` runs once after all hooks, picking up any
MODULES/HOOKS edits they made.

Wi-Fi is deliberately per-host, not default: wired-only machines must not
carry the stack. Desktop presets that need it add
`PACKAGES+=("iwd" "wireless-regdb")` and `hooks/iwd.sh` wires iwd as the
NetworkManager backend.

`YAY_PACKAGES` lists AUR packages, built and installed by the last chroot
module after `yay` itself is bootstrapped.

### Bootloader

| Variable         | Description                          | Default |
|------------------|--------------------------------------|---------|
| `EFI_MOUNTPOINT` | ESP mountpoint                       | `/boot` |
| `KERNEL_PARAMS`  | Extra kernel command-line parameters | `()`    |

systemd-boot only. Microcode initrds are picked up automatically; the
swapfile resume offset is appended to the entry when applicable.

### Services

```bash
SERVICES=(
    "fstrim.timer"
)
```

Each entry is passed verbatim to `systemctl enable` inside the chroot. The
array is only for units not tied to a `PACKAGES` entry (built-in systemd
timers, role-layer additions such as `sshd`); package-specific services are
enabled by that package's hook instead.

### Sleep

`HIBERNATE_DELAY` (a systemd timespan, e.g. `"4h"`) enables
suspend-then-hibernate with that delay. Empty keeps plain suspend.

## Presets

### `config/matebook.conf` — Huawei MateBook D16 2021

Desktop role. AMD Ryzen 5 4600H with integrated Vega 6: `amd-ucode`,
`mesa` + `vulkan-radeon` with amdgpu early KMS, `brightnessctl`, iwd Wi-Fi
stack, 16G swap partition, `HIBERNATE_DELAY="4h"`,
`acpi_enforce_resources=lax` for the platform's SMBus/ACPI conflict.

### `config/chuwi.conf` — CHUWI UBox

Desktop role. AMD Ryzen 5 6600H with integrated Radeon 660M: same AMD
graphics and Wi-Fi stack as matebook. 16G swap partition,
`HIBERNATE_DELAY="4h"`.

### `config/station.conf` — workstation

Server role — headless, no graphical session. AMD Ryzen 7 5800X3D with an
Nvidia RTX 4070 Ti: `nvidia-open` with early KMS and
`nvidia_drm.modeset=1 nvidia_drm.fbdev=1` (GBM consumers render without a
host compositor). `sshd` and `docker.service` are enabled from first boot via
the server role layer.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/voqse/arch-install/master/run.sh) --preset station
```

## Installation pipeline

| Step | Module | Description |
|------|--------|-------------|
| 0 | `run.sh` | Load preset; prompt for credentials, hostname, timezone, unset swap values |
| 1 | `01-pre-checks` | Assert UEFI mode, check internet, enable NTP |
| 2 | `02-disk` | Partition, format, mount under `/mnt` |
| 3 | `03-mirrors` | Mirrorlist from `MIRRORS` or reflector (`REFLECTOR_ARGS`) |
| 4 | `04-pacstrap` | `pacstrap -K /mnt <packages>` |
| 5 | `05-fstab` | `genfstab -U /mnt` |
| 6 | `06-chroot` | Copy scripts + serialised config, run `arch-chroot` |
| — | (chroot) timezone | `/etc/localtime`, `hwclock`, timesyncd |
| — | (chroot) localization | `locale-gen`, `locale.conf`, `vconsole.conf` |
| — | (chroot) hostname | `/etc/hostname`, `/etc/hosts` |
| — | (chroot) users | Root password, user account, `/etc/sudoers.d/wheel` |
| — | (chroot) bootloader | systemd-boot install + entry |
| — | (chroot) services | `systemctl enable` for `SERVICES` |
| — | (chroot) hooks | Per-package scripts from `hooks/` |
| — | (chroot) sleep | Suspend-then-hibernate (skipped when `HIBERNATE_DELAY` unset) |
| — | (chroot) initramfs | `mkinitcpio -P` |
| — | (chroot) yay | Build `yay`, install `YAY_PACKAGES` |

## CI

`lint.yml` runs on every push and pull request: `bash -n` syntax check over
all scripts, ShellCheck (`-x`, gating on errors), and a config-resolve smoke
test that sources `default.conf` plus each host preset and asserts the result
is sane (non-empty package set, hostname overridden, no duplicate packages or
services).
