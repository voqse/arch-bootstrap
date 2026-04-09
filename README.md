# arch-bootstrap

Modular, config-driven Arch Linux installation script that strictly follows
the official [Arch Linux Installation Guide](https://wiki.archlinux.org/title/Installation_guide).

Run it from the live ISO with a single command — or customise a preset file
and pass it with `--config` to get a fully unattended install.

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

# 4. Run
bash bootstrap.sh --config my.conf
```

At the end of the run you will be told to unmount and reboot:

```bash
umount -R /mnt
reboot
```

---

## Project structure

```
arch-bootstrap/
├── bootstrap.sh              # Main entry point
├── lib.sh                    # Shared helper functions
│
├── config/
│   ├── default.conf          # Base configuration preset (start here)
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
│   └── modules/              # In-chroot configuration (runs inside the new system)
│       ├── 01-timezone.sh    # Timezone + NTP
│       ├── 02-localization.sh# locale.gen, locale.conf, vconsole.conf
│       ├── 03-hostname.sh    # /etc/hostname, /etc/hosts
│       ├── 04-initramfs.sh   # mkinitcpio
│       ├── 05-users.sh       # Root password + user accounts + sudo
│       ├── 06-bootloader.sh  # GRUB (UEFI)
│       ├── 07-hooks.sh       # Per-package post-install hooks
│       └── 08-services.sh    # systemctl enable for SERVICES array
│
└── hooks/                    # Hook scripts (run in chroot, tied to packages)
    ├── networkmanager.sh     # Enable NetworkManager (legacy)
    ├── ufw.sh                # Configure UFW firewall rules
    └── gnome-appearance.sh   # Set solid #000 background for GNOME + GDM
```

---

## Configuration reference

Copy a preset and edit it:

```bash
cp config/default.conf config/my.conf
```

### Localization

| Variable  | Description                        | Default               |
|-----------|------------------------------------|-----------------------|
| `LOCALES` | Array of locales to uncomment      | `("en_US.UTF-8" "ru_RU.UTF-8")` |
| `LANG`    | System-wide language (`LANG=`)     | `en_US.UTF-8`         |
| `KEYMAP`  | Console keymap (vconsole.conf)     | `ruwin_alt_sh-UTF-8`  |
| `FONT`    | Console font (vconsole.conf)       | `cyr-sun16`           |
| `TIMEZONE`| Timezone path under /usr/share/zoneinfo | `Europe/Moscow`  |
| `NTP_ENABLED` | Enable systemd-timesyncd on first boot | `true`        |

### Disk

| Variable    | Description                                      | Default |
|-------------|--------------------------------------------------|---------|
| `DISK`      | Device path, e.g. `/dev/nvme0n1`. Empty = prompt | `""`    |
| `USE_SWAP`  | Create a swap partition                          | `true`  |
| `SWAP_SIZE` | Swap size, e.g. `16G` or `4096M`                | `16G`   |

Partition layout (GPT / UEFI, always):

| # | Size        | Type                  | Filesystem |
|---|-------------|-----------------------|------------|
| 1 | 512 MiB     | EFI System Partition  | FAT32      |
| 2 | `SWAP_SIZE` | Linux swap            | swap       |
| 3 | remainder   | Linux filesystem      | ext4       |

Swap is omitted when `USE_SWAP=false`.

### System identity

| Variable        | Description             | Default      |
|-----------------|-------------------------|--------------|
| `HOSTNAME`      | Machine hostname        | `archlinux`  |
| `USERS`         | Array of user entries   | see below    |
| `ROOT_PASSWORD` | Root password; empty = lock root | `""` |

**User entry format:** `"username:password:groups"`

- `password` can be a literal password, empty (locks the account), or `?` to
  be prompted interactively during installation.
- `groups` is a comma-separated list of supplementary groups.

```bash
USERS=(
    "alice:?:wheel,audio,video,storage"   # prompted at install time
    "bob:s3cr3t:audio"                    # set directly in config
)
```

### Mirrors

| Variable         | Description                                   | Default    |
|------------------|-----------------------------------------------|------------|
| `MIRROR_COUNTRY` | Country name passed to reflector              | `Russia`   |
| `MIRRORS`        | Explicit mirror URLs (overrides reflector)    | `()`       |

### Packages

```bash
BASE_PACKAGES=(          # Passed to pacstrap first; always installed
    "base"
    "linux"
    ...
)

PACKAGES=(               # Additional packages; may carry a hook
    "networkmanager"            # plain — no hook
    "ufw:ufw"                   # "ufw" package → runs hooks/ufw.sh
    "gnome-shell:gnome-appearance"
)

BOOTLOADER_PACKAGES=(    # Bootloader and related tools
    "grub"
    "efibootmgr"
)
```

### Bootloader (GRUB)

| Variable                | Description                                           | Default  |
|-------------------------|-------------------------------------------------------|----------|
| `BOOTLOADER`            | Bootloader type (only `grub` supported)               | `grub`   |
| `GRUB_BOOTLOADER_ID`    | Label in the EFI firmware boot menu                  | `GRUB`   |
| `GRUB_TIMEOUT`          | Seconds to wait before auto-boot (`0` = immediate)   | `5`      |
| `GRUB_TIMEOUT_STYLE`    | `menu` \| `countdown` \| `hidden`                    | `menu`   |
| `GRUB_DISABLE_OS_PROBER`| `true` = single-OS mode, no multi-boot scan           | `false`  |

Example — silent single-OS boot, EFI entry named "Linux Boot Manager":

```bash
GRUB_BOOTLOADER_ID="Linux Boot Manager"
GRUB_TIMEOUT=0
GRUB_TIMEOUT_STYLE="hidden"
GRUB_DISABLE_OS_PROBER=true
```

### Services

`SERVICES` is an array of systemd unit names that will be enabled inside the
chroot via `systemctl enable`:

```bash
SERVICES=(
    "NetworkManager"
    "bluetooth"
    "gdm"
    "fstrim.timer"
    "ufw"
)
```

### Per-package post-install hooks

Append `:hook_name` to a package entry; the matching `hooks/<hook_name>.sh`
is executed inside the chroot after all packages are installed:

```bash
PACKAGES=(
    "ufw:ufw"                       # runs hooks/ufw.sh
    "gnome-shell:gnome-appearance"  # runs hooks/gnome-appearance.sh
)
```

Create the hook script:

```bash
#!/usr/bin/env bash
# hooks/ufw.sh
ufw default deny incoming
ufw default allow outgoing
ufw --force enable
```

---

## Presets

### `config/default.conf`

Minimal base preset with sensible defaults. Start here for a new machine.

### `config/matebook-d16.conf`

Ready-to-use preset for the **Huawei MateBook D16 2021** (AMD Ryzen 5 4600H,
integrated Radeon Vega 6):

- GNOME desktop with Wayland / GDM
- PipeWire audio stack
- AMD open-source graphics (Mesa, vulkan-radeon, VA-API)
- NetworkManager + BlueZ
- UFW firewall (deny in / allow out)
- Solid black (#000000) background for desktop and login screen
- GRUB boots silently with no menu (EFI entry: "Linux Boot Manager")
- `fstrim.timer` for SSD health
- `fwupd` for firmware updates
- Timezone: Asia/Tomsk

```bash
bash bootstrap.sh --config config/matebook-d16.conf
```

---

## Installation pipeline

| Step | Module | Description |
|------|--------|-------------|
| 1 | `01-pre-checks` | Assert UEFI mode, ping internet, enable NTP |
| 2 | `02-disk` | Partition disk, format, mount under `/mnt` |
| 3 | `03-mirrors` | Rank mirrors with reflector or use explicit list |
| 4 | `04-pacstrap` | `pacstrap -K /mnt <all packages>` |
| 5 | `05-fstab` | `genfstab -U /mnt >> /mnt/etc/fstab` |
| 6 | `06-chroot` | Copies scripts + serialised config, runs `arch-chroot` |
| — | (chroot) timezone | `/etc/localtime`, `hwclock`, enable timesyncd |
| — | (chroot) localization | `locale-gen`, `locale.conf`, `vconsole.conf` |
| — | (chroot) hostname | `/etc/hostname`, `/etc/hosts` |
| — | (chroot) initramfs | `mkinitcpio -P` |
| — | (chroot) users | Root password, user accounts, `/etc/sudoers.d/wheel` |
| — | (chroot) bootloader | GRUB install + `grub-mkconfig` |
| — | (chroot) services | `systemctl enable` for each entry in `SERVICES` |
| — | (chroot) hooks | Per-package hook scripts |
