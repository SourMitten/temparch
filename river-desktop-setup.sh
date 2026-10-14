
[scrollback]
lines=10000

[cursor]
style=block
blink=yes

[colors]
alpha=0.95
background=1e1e2e
foreground=cdd6f4
regular0=45475a
regular1=f38ba8
regular2=a6e3a1
regular3=f9e2af
regular4=89b4fa
regular5=f5c2e7
regular6=94e2d5
regular7=bac2de
EOF

# ---- swaylock ------------------------------------------------------------------------
backup "$HOME/.config/swaylock/config"
cat > "$HOME/.config/swaylock/config" <<'EOF'
color=1e1e2e
font=JetBrainsMono Nerd Font
indicator-radius=100
indicator-thickness=8
ring-color=313244
key-hl-color=89b4fa
inside-color=1e1e2e
inside-ver-color=89dceb
inside-wrong-color=f38ba8
line-color=00000000
separator-color=00000000
text-color=cdd6f4
EOF

# ---- xdg-desktop-portal --------------------------------------------------------------
backup "$HOME/.config/xdg-desktop-portal/portals.conf"
cat > "$HOME/.config/xdg-desktop-portal/portals.conf" <<'EOF'
[preferred]
default=gtk
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.Screenshot=wlr
EOF

#==============================================================================
# 7. greetd + tuigreet (login manager) and the river session wrapper
#==============================================================================
info "Setting up greetd + tuigreet..."

# Session wrapper: sets the Wayland environment, then starts River Classic.
cat <<EOF | sudo tee /usr/local/bin/river-session >/dev/null
#!/bin/sh
# Session wrapper started by greetd/tuigreet. Sets the environment for the
# whole Wayland session, then replaces itself with River Classic.
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=river
export XDG_CURRENT_DESKTOP=river
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export SDL_VIDEODRIVER=wayland
export CLUTTER_BACKEND=wayland
export _JAVA_AWT_WM_NONREPARENTING=1
$GPUENV
exec river
EOF
sudo chmod +x /usr/local/bin/river-session

# greetd needs an unprivileged 'greeter' user (the Arch package normally
# creates it — create it if missing).
if ! id greeter &>/dev/null; then
    sudo useradd -r -s /usr/bin/nologin -M greeter
fi

cat <<'EOF' | sudo tee /etc/greetd/config.toml >/dev/null
[terminal]
# The virtual terminal where the greeter should run.
vt = 1

[default_session]
# tuigreet: a console greeter UI. --remember remembers your last session,
# --time shows a clock, --user-menu lets you pick the user.
command = "tuigreet --time --remember --user-menu --cmd /usr/local/bin/river-session"
user = "greeter"
EOF

# Avoid a conflict between greetd on tty1 and the default getty.
sudo systemctl disable getty@tty1.service 2>/dev/null || true
# Disable other display managers if one was enabled before.
for dm in sddm gdm lightdm lxdm ly; do
    if systemctl is-enabled "$dm.service" &>/dev/null; then
        warn "Disabling previously enabled display manager: $dm"
        sudo systemctl disable "$dm.service"
    fi
done
sudo systemctl enable greetd.service

#==============================================================================
# 8. Done
#==============================================================================
echo
info "All done! Reboot to land in the tuigreet login screen:   sudo reboot"
cat <<'EOF'

  ------------------------------------------------------------------
  Essential key bindings (Super = Windows key)
  ------------------------------------------------------------------
    Super + Return .......... terminal (foot)
    Super + D ............... application launcher (fuzzel)
    Super + V ............... clipboard history picker
    Super + Q ............... close window
    Super + Shift + E ....... log out (exit river)
    Ctrl + Alt + L .......... lock screen (swaylock)
    Super + J / K ........... focus next / previous window
    Super + Shift + J / K ... swap window
    Super + H / L ........... shrink / grow main area
    Super + 1-9 ............. switch to tag (workspace)
    Super + Shift + 1-9 ..... move window to tag
    Super + F ............... fullscreen
    Super + Space ........... floating on/off
    Print ................... screenshot -> clipboard
    Shift + Print ........... area screenshot -> clipboard
    Ctrl + Print ............ screenshot -> ~/Pictures/Screenshots
  ------------------------------------------------------------------
