# Arch Linux + River (Wayland) — Complete Installation Guide

This guide gives you a fully working Arch Linux system running **River**, a
dynamic tiling Wayland compositor, with **greetd + tuigreet** as the login
manager. It works in VirtualBox, VMware, QEMU/KVM and on bare metal
(AMD, Intel, NVIDIA).

**Two ways to use this guide:**

- **Automated (recommended):** run the two scripts that came with this guide
  (sections 2 and 4 below tell you exactly when).
- **Manual:** follow every step yourself — the scripts do nothing more than
  the steps in Part B.

---

## What you end up with

| Component | Choice | Purpose |
|---|---|---|
| Compositor | `river` (+ `rivertile`) | Tiling Wayland window manager |
| Login manager | `greetd` + `tuigreet` | Lightweight Wayland-native login screen |
| Terminal | `foot` | Fast Wayland-native terminal |
| Launcher | `fuzzel` | Application launcher / dmenu replacement |
| Status bar | `waybar` | Bar with river tags, window title, tray, volume… |
| Notifications | `mako` | Wayland notification daemon |
| Wallpaper | `swaybg` | Background |
| Lock / idle | `swaylock` + `swayidle` | Screen locking |
| Screenshots | `grim` + `slurp` | Full-screen and area screenshots |
| Clipboard | `wl-clipboard` + `cliphist` | Clipboard + history |
| Audio | `pipewire` + `wireplumber` | Modern audio stack |
| Portals | `xdg-desktop-portal-wlr` | Screen sharing, file choosers in Flatpak/sandboxed apps |
| Polkit | `polkit-gnome` | GUI authentication prompts |

Everything comes from the official Arch repositories — **no AUR required**.

---

## Part A — Automated path

### 1. Prepare the installation medium

**VirtualBox:** create a VM with these settings:

- Type: *Linux*, Version: *Arch Linux (64-bit)*
- RAM ≥ 4096 MB, 2+ CPUs, disk ≥ 20 GB
- **System → Enable EFI** (required)
- **Display → Graphics Controller: VMSVGA**, check **Enable 3D Acceleration**,
  Video Memory: 128 MB
- Mount the Arch ISO and boot it

**Bare metal:** write the ISO to a USB stick:

```bash
sudo dd bs=4M if=archlinux-*.iso of=/dev/sdX status=progress oflag=sync
```

Boot the machine from the stick in **UEFI mode** (disable Secure Boot, or set
it up later — the stock ISO does not boot with Secure Boot enabled).

### 2. Run the base installer (from the ISO)

On the ISO you are automatically root. Connect to the network first
(Ethernet just works; for Wi-Fi run `iwctl`, then `station wlan0 connect "SSID"`).

Get the two scripts onto the live system (USB stick, `scp`, or simply type the
relevant parts into a file), then:

```bash
chmod +x arch-base-install.sh
./arch-base-install.sh
```

It will ask for the target disk, hostname, username, password and timezone,
then partition the disk (512 MiB EFI + ext4 root), install the base system,
configure systemd-boot and create your user.

When it finishes:

```bash
umount -R /mnt
reboot    # remove the USB / unmount the ISO
```

### 3. Run the desktop setup (in the new system)

Log in as your user, copy `river-desktop-setup.sh` over, then:

```bash
bash river-desktop-setup.sh
```

It upgrades the system, **auto-detects your GPU / hypervisor** and installs
the right drivers, then installs and configures the whole River stack,
greetd and PipeWire. Reboot when it tells you to — you will land in the
tuigreet login screen. Press Enter, enter your password, and River starts.

Skip to **Part C — First boot & usage**.

---

## Part B — Manual path

### 1. Boot the ISO and prepare

```bash
# Verify UEFI mode (must print 64):
cat /sys/firmware/efi/fw_platform_size

# Wi-Fi only:
iwctl
[iwd]# station wlan0 connect "SSID"
[iwd]# quit

ping -c1 archlinux.org
timedatectl set-ntp true
```

### 2. Partition the disk

Example for `/dev/sda` (adapt for NVMe: `/dev/nvme0n1`, partitions are then
`p1`/`p2`):

```bash
sgdisk -Z /dev/sda                                 # wipe partition table
sgdisk -n1:0:+512MiB -t1:ef00 -c1:EFI /dev/sda     # EFI system partition
sgdisk -n2:0:0 -t2:8300 -c2:root /dev/sda          # root partition

mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2

mount /dev/sda2 /mnt
mount --mkdir /dev/sda1 /mnt/boot
```

### 3. Install the base system

```bash
# Pick microcode matching your CPU: intel-ucode or amd-ucode
pacstrap -K /mnt base linux linux-firmware networkmanager sudo vim git \
    man-db man-pages intel-ucode

genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

### 4. Configure the system (inside the chroot)

```bash
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime   # your timezone
hwclock --systohc

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "arch-river" > /etc/hostname

passwd                       # root password
useradd -m -G wheel -s /bin/bash river
passwd river                 # user password
EDITOR=vim visudo            # uncomment: %wheel ALL=(ALL:ALL) ALL

mkinitcpio -P

# Bootloader (systemd-boot, ESP mounted at /boot):
bootctl install
cat > /boot/loader/loader.conf <<'EOF'
default arch.conf
timeout 3
editor no
EOF
cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=UUID=$(findmnt -no UUID /) rw
EOF

systemctl enable NetworkManager
exit            # leave chroot
umount -R /mnt
reboot
```

### 5. GPU drivers

After rebooting, log in as your user, then:

```bash
sudo pacman -Syu

# Base (always):
sudo pacman -S mesa

# VirtualBox:
sudo pacman -S virtualbox-guest-utils
sudo systemctl enable vboxservice

# VMware:
sudo pacman -S open-vm-tools

# QEMU/KVM:
sudo pacman -S spice-vdagent qemu-guest-agent
sudo systemctl enable qemu-guest-agent

# Bare metal — AMD:
sudo pacman -S vulkan-radeon libva-mesa-driver mesa-vdpau

# Bare metal — Intel:
sudo pacman -S vulkan-intel intel-media-driver libva-intel-driver

# Bare metal — NVIDIA (see section 7 as well):
sudo pacman -S nvidia-open nvidia-utils libva-nvidia-driver
#   - add 'nvidia nvidia_modeset nvidia_uvm nvidia_drm' to MODULES=(...) in
#     /etc/mkinitcpio.conf, then: sudo mkinitcpio -P
#   - append to the options line in /boot/loader/entries/arch.conf:
#       nvidia_drm.modeset=1 nvidia_drm.fbdev=1
```

### 6. Install and configure the River desktop

```bash
sudo pacman -S --needed \
    river foot fuzzel waybar mako swaybg swaylock swayidle \
    grim slurp wl-clipboard cliphist xdg-user-dirs xdg-utils \
    xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
    polkit-gnome network-manager-applet brightnessctl playerctl libnotify \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber pavucontrol \
    ttf-dejavu noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd otf-font-awesome \
    greetd greetd-tuigreet

# PipeWire runs per-user:
sudo systemctl --global enable pipewire pipewire-pulse wireplumber
```

**greetd** — create the session wrapper:

```bash
sudo tee /usr/local/bin/river-session <<'EOF'
#!/bin/sh
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=river
export XDG_CURRENT_DESKTOP=river
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export SDL_VIDEODRIVER=wayland
export _JAVA_AWT_WM_NONREPARENTING=1
# NVIDIA only:
# export LIBVA_DRIVER_NAME=nvidia
# export __GLX_VENDOR_LIBRARY_NAME=nvidia
# export GBM_BACKEND=nvidia-drm
# export WLR_NO_HARDWARE_CURSORS=1
exec river
EOF
sudo chmod +x /usr/local/bin/river-session
```

Then the greetd config:

```bash
sudo tee /etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --user-menu --cmd /usr/local/bin/river-session"
user = "greeter"
EOF

sudo systemctl disable getty@tty1        # avoid tty1 conflict
sudo systemctl enable greetd
```

**River and friends** — the configuration files (`~/.config/river/init`,
waybar, fuzzel, mako, foot, swaylock, portals) are written automatically by
`river-desktop-setup.sh`. If you are going fully manual, extract them from
that script (section 6 of the script is nothing but `cat >` blocks you can
copy verbatim). Make sure the init file is executable:

```bash
chmod +x ~/.config/river/init
```

Reboot: `sudo reboot`.

---

## Part C — First boot & usage

At the tuigreet screen press **Enter**, type your password, Enter again.
River starts with waybar on top.

### Key bindings (Super = Windows key)

| Keys | Action |
|---|---|
| Super + Return | Terminal (foot) |
| Super + D | Application launcher (fuzzel) |
| Super + V | Clipboard history picker |
| Super + Q | Close window |
| Super + Shift + E | Log out (exit river) |
| Ctrl + Alt + L | Lock screen |
| Super + J / K | Focus next / previous window |
| Super + Shift + J / K | Swap window |
| Super + Shift + Return | Move window to main area |
| Super + H / L | Shrink / grow main area ratio |
| Super + Shift + H / L | More / fewer main-area windows |
| Super + 1–9 | Switch to tag (workspace) |
| Super + Shift + 1–9 | Move window to tag |
| Super + Ctrl + 1–9 | Show tag additionally |
| Super + 0 | Show all tags |
| Super + F | Fullscreen |
| Super + Space | Toggle floating |
| Super + Tab | Focus next monitor |
| Print / Shift+Print / Ctrl+Print | Screenshot full / area / to file |

### River concepts in one minute

River does not have workspaces — it has **tags**. Every window carries a set of
tags, every monitor shows a set of tags. `Super+2` shows tag 2; a window can
sit on several tags at once. Tiling layout is generated by the external
`rivertile` process (spawned in the init file) — main area on the left, stack
on the right.

---

## Part D — NVIDIA notes

River is wlroots-based, which historically meant pain on NVIDIA. With the
495+ proprietary drivers and GBM it works, but you need:

1. Kernel mode setting: `nvidia_drm.modeset=1` (and ideally
   `nvidia_drm.fbdev=1`) on the kernel command line — the setup script adds
   this to your systemd-boot entry automatically.
2. Early KMS: `nvidia nvidia_modeset nvidia_uvm nvidia_drm` in the
   `MODULES=(...)` array of `/etc/mkinitcpio.conf`, then `sudo mkinitcpio -P`.
3. The environment variables in `/usr/local/bin/river-session`
   (`LIBVA_DRIVER_NAME=nvidia`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`,
   `GBM_BACKEND=nvidia-drm`, `WLR_NO_HARDWARE_CURSORS=1`) — the script writes
   these automatically when it detects an NVIDIA GPU.
4. `nvidia-open` requires a Turing GPU or newer (GTX 16xx / RTX 20xx+).
   Older cards: use `nvidia` instead.

If you can choose your hardware: AMD or Intel gives a completely trouble-free
wlroots experience.

---

## Part E — Troubleshooting

**Black screen / immediate crash in a VM (VirtualBox):**
Make sure the VM uses **VMSVGA + 3D acceleration** and EFI. If it still fails,
test with the software renderer — add `export WLR_RENDERER=pixman` at the top
of `/usr/local/bin/river-session`. Slow but proves the stack works; the fix is
then VM display settings, not River.

**River doesn't start at all:** switch to tty2 (`Ctrl+Alt+F2`), log in, and
run `river > /tmp/river.log 2>&1` to see the error.

**"couldn't open /dev/dri/card0" / seat errors:** your user must get a logind
session — this happens automatically when logging in via greetd. If you start
river from a TTY instead, install `seatd`, enable it
(`sudo systemctl enable --now seatd`), add yourself to the `seat` group and
export `LIBSEAT_BACKEND=seatd`.

**Screen sharing (e.g. Firefox/Discord/Zoom) doesn't work:**
`xdg-desktop-portal-wlr` must be running and the session environment must be
imported — the init file already runs
`dbus-update-activation-environment --systemd ...`. Restart the portal after
login if needed: `systemctl --user restart xdg-desktop-portal`.

**No sound:** check `systemctl --user status pipewire wireplumber`, unmute in
`pavucontrol`.

**Re-running `~/.config/river/init` duplicates autostarted programs.** Log out
and in instead (or kill the duplicates).

**HiDPI display:** scale per monitor, e.g.
`riverctl output HDMI-A-1 scale 2` in the init file; list outputs with
`riverctl list-outputs` (or `wlr-randr` if installed).

---

## Part F — Optional extras (from the AUR)

Once comfortable, install an AUR helper (`yay` or `paru`) and consider:

- `i3bar-river` — alternative minimal bar
- `wideriver` / `rivercarro` / `stacktile` — alternative layout generators
- `wlogout` — graphical logout/power menu
- `swayosd` — on-screen volume/brightness indicators
- `nwg-look` — GTK theming GUI

Also see the official docs: `man river`, `man riverctl`, `man rivertile`, and
the Arch Wiki pages *River*, *greetd*, *Wayland* and *PipeWire*.
