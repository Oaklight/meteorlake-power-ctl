# meteorlake-power-ctl

Power profile manager for Intel Meteor Lake laptops on Linux. Atomically switches between three profiles, controlling TLP, SMT, intel-lpmd, P-core parking, and display refresh rate.

Tested on ThinkPad X1 Carbon Gen 12 (Core Ultra 7 155H) with Arch Linux.

## Profiles

| Profile | Turbo | SMT | P-cores | Hz | EPP | Platform | Typical PkgWatt |
|---------|-------|-----|---------|-----|-----|----------|-----------------|
| **performance** | on | on (22T) | all | 120 | balance_performance | balanced | ~8W |
| **balanced** | off | off (16T) | all | 60 | balance_power | balanced | ~5W |
| **power-saver** | off | off (11T) | parked | 60 | power | low-power | ~3.7W |

## Install

### From AUR

```bash
yay -S mtl-power-ctl
```

### Manual

```bash
git clone https://github.com/oaklight/meteorlake-power-ctl.git
cd meteorlake-power-ctl
sudo make install
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

### Keybinding (niri example)

```kdl
// In ~/.config/niri/config.kdl
Mod+B { spawn "sudo" "power-ctl" "toggle"; }
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

1. **Unpark CPUs** (if switching away from power-saver)
2. **SMT** — enable/disable HyperThreading at runtime
3. **Park P-cores** (if entering power-saver) — offline P-cores except CPU 0
4. **TLP** — switch EPP, turbo, platform profile, GPU, WiFi power save
5. **intel-lpmd** — write tuned thresholds and restart daemon
6. **Display** — switch eDP refresh rate via niri IPC

### Why park P-cores?

On Meteor Lake, P-cores have high leakage current even in C6 idle state. The 155H has 6 P-cores that collectively consume ~1.4W at idle. Parking them (offlining via sysfs) forces the scheduler to use only E-cores and LP E-cores, reducing package power from ~5W to ~3.7W.

### Why disable SMT on battery?

HyperThreading prevents P-cores from entering deep C-states (C6) because both sibling threads must be idle simultaneously. Disabling SMT simplifies the scheduler topology and improves C-state residency. Intel removed HT from Arrow Lake and Lunar Lake for similar reasons.

## Meteor Lake C-state notes

- Core C-state path: C1E → C6 → C10 (no C3/C7/C8/C9)
- Package C-state path: PC2 → PC6 → PC8 → PC10 (no PC3)
- **PC6+ is only reachable during s2idle suspend**, not during normal idle. Pkg%pc6=0 is architectural, not a bug.
- S0ix is boot-dependent due to CSME firmware initialization differences.

## License

MIT
