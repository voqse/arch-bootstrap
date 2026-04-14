# arch-bootstrap

Modular, config-driven Arch Linux installation script that strictly follows
the official [Arch Linux Installation Guide](https://wiki.archlinux.org/title/Installation_guide).

Preset files define the target machine's packages, timezone, hostname, and
services. Credentials (username, user password, root password) are always
collected interactively at the start of the run and are never stored in
preset files.

---

## Quick start

> **Security note:** Always download and review scripts before executing them.

```bash
# 1. Boot the Arch Linux ISO and connect to the internet
# 2. Download the script and a preset
curl -fsSL https://raw.githubusercontent.com/voqse/arch-bootstrap/main/bootstrap.sh -o bootstrap.sh
curl -fsSL https://raw.githubusercontent.com/voqse/arch-bootstrap/main/config/default.conf -o my.conf

# 3. Edit the preset to match your hardware and preferences
nano my.conf

# 4. Run — you will be asked for username and passwords before anything starts
bash bootstrap.sh --config my.conf
```

The script will ask for credentials first, then install and configure the
system without further interaction. When finished:

```bash
umount -R /mnt
reboot
```

---

## Project structure

```
arch-bootstrap/
├── bootstrap.sh              # Main entry point; interactive credential prompt
├── lib.sh                    # Shared helper functions
│
├── config/
│   ├── default.conf          # Base preset — start here for a new machine
│   └── matebook-d16.conf     # Huawei MateBook D16 2021 (Ryzen 4600H / GNOME)
│
├── modules/                  # Pre-chroot pipeline (runs on the live ISO)
│   ├── 01-pre-checks.sh      # Verify UEFI, internet, NTP
│   ├── 02-disk.sh            # Partition, format, mount
│   ├── 03-mirrors.sh         # Mirror selection via reflector
│   ├── 04-pacstrap.sh        # Install packages into /mnt
│   ├── 05-fstab.sh           # Generate /etc/fstab
│   └── 06-chroot.sh          # Copy scripts, enter arch-chroot
│
├── chroot/
│   ├── configure.sh          # Chroot entry point
│   └── modules/              # In-chroot configuration
│       ├── 01-timezone.sh    # Timezone + systemd-timesyncd
│       ├── 02-localization.sh# locale.gen, locale.conf, vconsole.conf
│       ├── 03-hostname.sh    # /etc/hostname, /etc/hosts
│       ├── 04-initramfs.sh   # mkinitcpio
│       ├── 05-users.sh       # Root password + user accounts + sudoers
│       ├── 06-bootloader.sh  # GRUB (UEFI)
│       ├── 07-hooks.sh       # Per-package configuration scripts
│       └── 08-services.sh    # systemctl enable for SERVICES array
│
└── hooks/                    # Per-package configuration scripts
    ├── gnome-shell.sh        # GNOME appearance — solid black background
    ├── networkmanager.sh     # Enable NetworkManager (legacy compatibility)
    └── ufw.sh                # UFW rules — deny incoming, allow outgoing
```

---

## Configuration reference

Copy a preset and edit it:

```bash
cp config/default.conf config/my.conf
bash bootstrap.sh --config config/my.conf
```

### Localization

| Variable  | Description                          | Default                          |
|-----------|--------------------------------------|----------------------------------|
| `LOCALES` | Locales to uncomment in `locale.gen` | `("en_US.UTF-8" "ru_RU.UTF-8")` |
| `LANG`    | System-wide language (`LANG=`)       | `en_US.UTF-8`                    |
| `KEYMAP`  | Console keymap (`vconsole.conf`)     | `ruwin_alt_sh-UTF-8`             |
| `FONT`    | Console font (`vconsole.conf`)       | `cyr-sun16`                      |

> **Timezone is not a preset value.**
> It is always prompted interactively at the start of each run.
> `systemd-timesyncd` NTP is always enabled — no config flag needed.

### Disk

| Variable     | Description                                                  | Default       |
|--------------|--------------------------------------------------------------|---------------|
| `DISK`       | Device path, e.g. `/dev/nvme0n1`. Empty = prompt            | `""`          |
| `SWAP_TYPE`  | `file` — swapfile at `/swap/swapfile`; `partition` — dedicated swap partition; `none` — no swap | `file` |
| `SWAP_SIZE`  | Swap size, e.g. `16G` or `4096M`                            | `16G`         |

Partition layout (GPT / UEFI only):

`SWAP_TYPE=file` or `none`:

| # | Size      | Type                 | Filesystem |
|---|-----------|----------------------|------------|
| 1 | 512 MiB   | EFI System Partition | FAT32      |
| 2 | remainder | Linux filesystem     | ext4       |

Swap file is created at `/swap/swapfile` and picked up by `genfstab`.

`SWAP_TYPE=partition`:

| # | Size        | Type                 | Filesystem |
|---|-------------|----------------------|------------|
| 1 | 512 MiB     | EFI System Partition | FAT32      |
| 2 | `SWAP_SIZE` | Linux swap           | swap       |
| 3 | remainder   | Linux filesystem     | ext4       |

### System identity

| Variable   | Description      | Default      |
|------------|------------------|--------------|
| `HOSTNAME` | Machine hostname | `archlinux`  |

> **Credentials and timezone are not in preset files.**
> Username, user password, root password, and timezone are asked interactively at
> the very beginning of the installation run.

### Packages

```bash
BASE_PACKAGES=(       # Passed to pacstrap first; always installed
    "base"
    "linux"
    "linux-firmware"
    "amd-ucode"       # add for AMD CPUs
)

PACKAGES=(            # Additional packages; optionally with a config hook
    "networkmanager"              # plain — no hook
    "ufw:ufw"                     # explicit hook → runs hooks/ufw.sh
    "gnome-shell"                 # auto hook  → runs hooks/gnome-shell.sh
)

BOOTLOADER_PACKAGES=( # Bootloader-related packages
    "grub"
    "efibootmgr"
)
```

#### Per-package configuration scripts

Any package entry can carry a configuration script from the `hooks/`
directory. Two ways to attach one:

1. **Auto-detection** — create `hooks/<package-name>.sh`. It runs
   automatically whenever that package appears in `PACKAGES`.
2. **Explicit name** — use `"package:hook-name"` syntax to run
   `hooks/<hook-name>.sh`.

```bash
# hooks/gnome-shell.sh — runs automatically after gnome-shell is installed
dconf update          # apply pre-written dconf overrides

# hooks/ufw.sh — called via explicit "ufw:ufw"
ufw default deny incoming
ufw default allow outgoing
ufw --force enable
```

Scripts execute inside `arch-chroot` after all packages have been installed,
so full system tools (dconf, systemctl, etc.) are available.

### Bootloader

| Variable                 | Description                                         | Default               |
|--------------------------|-----------------------------------------------------|-----------------------|
| `BOOTLOADER`             | Bootloader type: `systemd-boot` (default) or `grub` | `systemd-boot`        |
| `EFI_MOUNTPOINT`         | Where the ESP is mounted                            | `/boot`               |
| `GRUB_BOOTLOADER_ID`     | EFI firmware boot-menu label (GRUB only)            | `Linux Boot Manager`  |
| `GRUB_TIMEOUT`           | Seconds before auto-boot (`0` = immediate; GRUB only) | `0`                 |
| `GRUB_TIMEOUT_STYLE`     | `menu` \| `countdown` \| `hidden` (GRUB only)      | `hidden`              |
| `GRUB_DISABLE_OS_PROBER` | `true` = skip multi-boot probe (GRUB only)          | `true`                |

**systemd-boot** (default) — silent instant boot, microcode auto-detected,
swapfile resume offset written to the boot entry automatically.

To use **GRUB** instead (e.g. for dual-boot):

```bash
BOOTLOADER="grub"
BOOTLOADER_PACKAGES=("grub" "efibootmgr")        # add "os-prober" for multi-boot
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE="menu"
GRUB_DISABLE_OS_PROBER=false
```

### Services

```bash
SERVICES=(
    "NetworkManager"
    "bluetooth"
    "gdm"
    "fstrim.timer"
    "ufw"
)
```

Each entry is passed verbatim to `systemctl enable` inside the chroot.

---

## Presets

### `config/default.conf`

Minimal base preset. Contains only what is needed for a functional system.
All GRUB, NTP, and mirror settings are already at sensible defaults — you
only need to override what differs for your machine.

### `config/matebook-d16.conf`

Ready-to-use preset for the **Huawei MateBook D16 2021**
(AMD Ryzen 5 4600H, integrated Radeon Vega 6):

| Setting | Value |
|---------|-------|
| Timezone | Asia/Tomsk |
| Hostname | matebook |
| Desktop | GNOME (Wayland / GDM) |
| Audio | PipeWire |
| GPU | Mesa + vulkan-radeon + libva-mesa-driver |
| Network | NetworkManager |
| Bluetooth | BlueZ |
| Firewall | UFW (deny in / allow out) |
| Background | Solid black `#000000` (desktop + GDM) |
| Boot | systemd-boot (default) — silent instant boot |
| SSD | `fstrim.timer` enabled |
| Firmware | `fwupd` + `fwupd-refresh.timer` |

```bash
bash bootstrap.sh --config config/matebook-d16.conf
```

---

## Installation pipeline

| Step | Module | Description |
|------|--------|-------------|
| 0 | bootstrap.sh | Ask username, user password, root password |
| 1 | `01-pre-checks` | Assert UEFI mode, ping internet, enable NTP |
| 2 | `02-disk` | Partition disk, format, mount under `/mnt` |
| 3 | `03-mirrors` | Use default Arch mirrorlist (reflector if available) |
| 4 | `04-pacstrap` | `pacstrap -K /mnt <all packages>` |
| 5 | `05-fstab` | `genfstab -U /mnt >> /mnt/etc/fstab` |
| 6 | `06-chroot` | Copy scripts + serialised config, run `arch-chroot` |
| — | (chroot) timezone | `/etc/localtime`, `hwclock`, enable timesyncd |
| — | (chroot) localization | `locale-gen`, `locale.conf`, `vconsole.conf` |
| — | (chroot) hostname | `/etc/hostname`, `/etc/hosts` |
| — | (chroot) initramfs | `mkinitcpio -P` |
| — | (chroot) users | Root password, user account, `/etc/sudoers.d/wheel` |
| — | (chroot) bootloader | systemd-boot or GRUB install + config |
| — | (chroot) services | `systemctl enable` for each entry in `SERVICES` |
| — | (chroot) hooks | Per-package configuration scripts from `hooks/` |
