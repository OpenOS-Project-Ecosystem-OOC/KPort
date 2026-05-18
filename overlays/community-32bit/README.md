# community-32bit overlay

Lightweight packages for i686 (32-bit x86) systems.

Qt 6 and KDE Frameworks 6 require a 64-bit target and cannot be built for
i686. This overlay provides packages that still build and run on 32-bit:
a complete LXQt 1.4.0 desktop environment, terminal emulators, and utilities.

## Qt version note

**LXQt 2.0+ requires Qt 6 and does not build on i686.** This overlay targets
**LXQt 1.4.0**, the last Qt 5-based release (November 2023). Qt 5.15 LTS
supports i686 and remains the correct toolkit for 32-bit desktop software.

If you need a newer LXQt, you need 64-bit hardware.

## Package tree

```
lxqt/                         LXQt 1.4.0 desktop environment
  lxqt-build-tools/           CMake modules (build-time only)
  libqtxdg/                   Qt5 XDG standards library
  liblxqt/                    Core LXQt library
  lxqt-menu-data/             XDG menu definitions (data, any arch)
  lxqt-themes/                QSS stylesheets and wallpapers (data, any arch)
  lxqt-session/               Session manager
  lxqt-panel/                 Desktop panel
  libfm-qt/                   File management library
  pcmanfm-qt/                 File manager and desktop manager
  qtermwidget/                Terminal emulator widget library
  qterminal/                  Terminal emulator
  lxqt-config/                Configuration centre
  lxqt-powermanagement/       Power management daemon
  lximage-qt/                 Image viewer

utils/
  terminal/xterm/             Minimal X11 terminal (reference pacscript)
```

## Scope

**Included:**
- LXQt 1.4.0 (Qt5) — full desktop environment for i686
- Terminal emulators (xterm, qterminal)
- Lightweight file managers (PCManFM-Qt)
- System utilities with no Qt6 dependency

**Excluded:**
- Anything that depends on Qt 6 or KDE Frameworks 6
- LXQt 2.0+ (Qt6-only, no 32-bit support)
- Packages requiring a 64-bit address space (Chromium, Electron, etc.)
- KDE Plasma desktop components

## Package format conventions

Pacscripts here follow the standard KPort format with three i686-specific
conventions:

1. Set `KCPU_MIN` to `i686-baseline` or `i686-sse3` (not `x86-64-*`).
   Omit `KCPU_MIN` entirely for pure data packages (themes, menu data).
2. Set `KGPU_MIN` to `gpu-sw`, `gpu-gl2`, or `gpu-gl4` — never `gpu-vk*`.
3. Pass `-m32` via `CMAKE_C_FLAGS` / `CMAKE_CXX_FLAGS` for all compiled
   packages. Use `${CFLAGS:--m32}` to allow the build environment to
   override (e.g. cross-compilation toolchains set their own flags).

## sha256sums

All pacscripts in this overlay use `sha256sums=("SKIP")` as placeholders.
Before enabling this overlay in production, replace each `SKIP` with the
actual checksum from the upstream release page, or run:

```bash
scripts/kport/fill-sha256.sh overlays/community-32bit
```

## Enabling this overlay

Add the following to `config/repositories.yml`:

```yaml
- name: community-32bit
  description: "Lightweight i686 packages"
  url: https://github.com/your-org/kport-community-32bit
  priority: 15
  enabled: true
  auto_sync: true
```

Or for local development, set `enabled: true` in `overlays/community-32bit/metadata.yml`.
