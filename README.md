# arch-bootstrap

Modular, config-driven Arch Linux installation script that follows the
official [Arch Linux Installation Guide](https://wiki.archlinux.org/title/Installation_guide).

---

## Quick start (from the Arch ISO)

> **Security note:** Always review scripts before executing them.
> Download and inspect the files first, then run locally.

```bash
curl -fsSL https://raw.githubusercontent.com/voqse/arch-bootstrap/main/bootstrap.sh -o bootstrap.sh
curl -fsSL https://raw.githubusercontent.com/voqse/arch-bootstrap/main/config/default.conf -o my.conf
# Review both files, then:
bash bootstrap.sh --config my.conf
```

---

## Project structure

```
arch-bootstrap/
├── bootstrap.sh            # Main entry point
├── lib.sh                  # Shared helper functions
├── config/
│   └── default.conf        # Default configuration preset
├── modules/                # Pre-chroot installation modules
│   ├── 01-pre-checks.sh    # UEFI check, internet, NTP
│   ├── 02-disk.sh          # Disk partitioning, formatting, mounting
│   ├── 03-mirrors.sh       # Mirror selection via reflector
│   ├── 04-pacstrap.sh      # Package installation (pacstrap)
│   ├── 05-fstab.sh         # /etc/fstab generation
│   └── 06-chroot.sh        # Copies scripts into /mnt, runs arch-chroot
├── chroot/
│   ├── configure.sh        # Chroot entry point
│   └── modules/            # In-chroot configuration modules
│       ├── 01-timezone.sh
│       ├── 02-localization.sh
│       ├── 03-hostname.sh
│       ├── 04-initramfs.sh
│       ├── 05-users.sh
│       ├── 06-bootloader.sh
│       └── 07-hooks.sh     # Per-package post-install hooks
└── hooks/                  # Post-install hook scripts
    └── networkmanager.sh   # Example: enable NetworkManager
```

---

## Configuration

Copy `config/default.conf` and edit it:

```bash
cp config/default.conf config/my.conf
```

| Variable | Description | Default |
|---|---|---|
| `LOCALES` | Array of locales to enable | `("en_US.UTF-8" "ru_RU.UTF-8")` |
| `LANG` | System language | `en_US.UTF-8` |
| `KEYMAP` | Console keymap | `ruwin_alt_sh-UTF-8` |
| `FONT` | Console font | `cyr-sun16` |
| `TIMEZONE` | Timezone (zoneinfo path) | `Europe/Moscow` |
| `DISK` | Target disk (e.g. `/dev/sda`). Leave empty to select interactively. | `""` |
| `USE_SWAP` | Create a swap partition | `true` |
| `SWAP_SIZE` | Swap partition size (e.g. `16G`, `4096M`) | `16G` |
| `HOSTNAME` | Machine hostname | `archlinux` |
| `USERS` | Array of `"user:password:groups"` entries | `("user::wheel,audio,video,storage")` |
| `ROOT_PASSWORD` | Root password. Leave empty to lock root. | `""` |
| `MIRROR_COUNTRY` | Country for reflector mirror selection | `Russia` |
| `MIRRORS` | Explicit mirror URLs (overrides reflector) | `()` |
| `BASE_PACKAGES` | Always-installed base packages | see config |
| `PACKAGES` | User packages, optionally with hooks: `"pkg:hook_name"` | see config |
| `BOOTLOADER` | Bootloader to install | `grub` |
| `BOOTLOADER_PACKAGES` | Bootloader packages | `("grub" "efibootmgr" "os-prober")` |

### Disk layout

Partitioning is always GPT/UEFI:

| # | Size | Type | Filesystem |
|---|---|---|---|
| 1 | 512 MiB | EFI System Partition | FAT32 |
| 2 | `SWAP_SIZE` | Linux swap | swap |
| 3 | remainder | Linux filesystem | ext4 |

Swap partition is omitted when `USE_SWAP=false`.

### Per-package post-install hooks

Append a hook name to any package entry in `PACKAGES`:

```bash
PACKAGES=(
    "networkmanager:networkmanager"   # runs hooks/networkmanager.sh in chroot
    "vim"                             # no hook
)
```

Create the corresponding `hooks/<hook_name>.sh`:

```bash
#!/usr/bin/env bash
# hooks/networkmanager.sh
systemctl enable NetworkManager
```

---

## Installation pipeline

1. **Pre-checks** — verify UEFI, internet, sync clock
2. **Disk** — partition, format, mount
3. **Mirrors** — rank mirrors with reflector
4. **pacstrap** — install packages
5. **fstab** — generate `/etc/fstab`
6. **chroot** — configure the new system:
   - Time zone
   - Localization (locale.gen, locale.conf, vconsole.conf)
   - Hostname and /etc/hosts
   - Initramfs (mkinitcpio)
   - Root password and user accounts
   - Boot loader (GRUB)
   - Post-install package hooks
