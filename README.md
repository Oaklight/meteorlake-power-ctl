# meteorlake-power-ctl

Power profile manager for Intel Meteor Lake laptops on Linux. Atomically switches between three profiles, controlling TLP, SMT, intel-lpmd, P-core parking, and display refresh rate.

Tested on ThinkPad X1 Carbon Gen 12 (Core Ultra 7 155H) with Arch Linux.

## Profiles

| Profile | Turbo | SMT | Cores | Hz | EPP | Platform | PkgWatt |
|---------|-------|-----|-------|-----|-----|----------|---------|
| **performance** | on | on | 6Px2+8E+2LP (22T) | 120 | balance_performance | balanced | ~8W |
| **balanced** | on 80% | off | 6P+8E+2LP (16T) | 60 | balance_power | balanced | ~5W |
| **power-saver** | off | off | 2P+4E+2LP (8T) | 60 | power | low-power | ~3.7W |

## Install

### From AUR

```bash
# Using any AUR helper, e.g.:
paru -S mtl-power-ctl
# or: yay -S mtl-power-ctl
```

### Manual

```bash
git clone https://github.com/oaklight/meteorlake-power-ctl.git
cd meteorlake-power-ctl
sudo make install
sudo power-ctl install   # deploy udev hooks for auto AC/battery switching
```

## Usage

```bash
# Cycle through profiles (performance → balanced → power-saver → ...)
sudo power-ctl toggle

# Set a specific profile
sudo power-ctl toggle balanced
sudo power-ctl toggle power-saver
sudo power-ctl toggle performance

# Show current status (no sudo needed)
power-ctl status

# Show version
power-ctl --version
```

### Automatic AC/battery switching

After `sudo power-ctl install`, udev rules and systemd services are deployed:

- **Plug AC** → switches to `performance` (only if currently on `balanced`)
- **Unplug AC** → switches to `balanced` (only if currently on `performance`)
- **Manual selections are never overridden** — if you chose `power-saver` or manually set `balanced` on AC, plug/unplug events won't change it

The mechanism is:

```
udev power_supply event
  → systemd starts power-ctl-on-{ac,battery}.service (async, non-blocking)
    → power-ctl on-ac / power-ctl on-battery
```

Using `TAG+="systemd"` + `SYSTEMD_WANTS` instead of udev `RUN` because power-ctl needs time to unpark CPUs, restart lpmd, and switch display refresh rate — udev `RUN` has a short timeout and blocks the event queue.

### Keybinding (niri example)

```kdl
// In ~/.config/niri/config.kdl

// Interactive profile selector popup
Mod+B { spawn "kitty" "--class" "power-selector" "--title" "Power Profile"
    "-o" "remember_window_size=no" "-o" "initial_window_width=52c"
    "-o" "initial_window_height=12c" "-o" "confirm_os_window_close=0"
    "/path/to/power-profile-selector"; }

// Quick status popup
Mod+Shift+B { spawn "kitty" "--class" "power-status" "--title" "Power Status"
    "-o" "remember_window_size=no" "-o" "initial_window_width=52c"
    "-o" "initial_window_height=14c" "-o" "confirm_os_window_close=0"
    "sh" "-c" "power-ctl status; echo; read -n1"; }

// Float the popup windows
window-rule {
    match app-id="power-selector"
    match app-id="power-status"
    open-floating true
    open-focused true
}
```

For passwordless sudo, add to `/etc/sudoers.d/power-ctl`:

```
youruser ALL=(ALL) NOPASSWD: /usr/bin/power-ctl
```

## Requirements

- Python ≥ 3.10
- [TLP](https://linrunner.de/tlp/) — power management framework
- [libnotify](https://gitlab.gnome.org/GNOME/libnotify) — desktop notifications
- [upower](https://upower.freedesktop.org/) — battery info

### Optional

- [intel-lpmd](https://github.com/intel/intel-lpmd) — Low Power Mode Daemon for LP E-core scheduling
- [niri](https://github.com/YaLTeR/niri) — display refresh rate switching via IPC

## How it works

Each profile applies settings atomically in the correct order:

1. **Unpark all CPUs** + enable SMT (so topology detection works on full core set)
2. **Classify CPUs** — P-core (has SMT sibling), E-core, LP E-core (by base_frequency)
3. **Park selected cores** — power-saver parks 5 physical P-cores + 4 E-cores
4. **Disable SMT** (balanced/power-saver) — parked siblings also go offline
5. **TLP** — switch EPP, turbo, platform profile, GPU, WiFi power save
6. **intel-lpmd** — write per-profile thresholds and restart daemon
7. **Display** — switch eDP refresh rate via niri IPC (120Hz / 60Hz)

### Why park P-cores?

On Meteor Lake, P-cores have high leakage current even in C6 idle state. The 155H has 6 P-cores that collectively consume ~1.4W at idle. Parking them (offlining via sysfs) forces the scheduler to use only E-cores and LP E-cores, reducing package power from ~5W to ~3.7W.

### Why disable SMT on battery?

HyperThreading prevents P-cores from entering deep C-states (C6) because both sibling threads must be idle simultaneously. Disabling SMT simplifies the scheduler topology from P×2+E+LP to P+E+LP and improves C-state residency. Intel removed HT from Arrow Lake and Lunar Lake for similar reasons.

### Why not use max_perf_pct to limit frequency?

With turbo off, `max_perf_pct` is relative to base frequency (1.4GHz on 155H P-cores), so 80% = 1.12GHz — too slow for interactive use. Instead, balanced keeps turbo on but caps at 80% of turbo max (~3.6GHz), giving burst capability without sustained high power draw.

## Meteor Lake C-state notes

- Core C-state path: C1E → C6 → C10 (no C3/C7/C8/C9)
- Package C-state path: PC2 → PC6 → PC8 → PC10 (no PC3)
- **PC6+ is only reachable during s2idle suspend**, not during normal idle. `Pkg%pc6=0` is architectural, not a bug.
- S0ix is boot-dependent due to CSME firmware initialization differences.

## License

MIT
