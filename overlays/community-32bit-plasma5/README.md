# community-32bit-plasma5 overlay

KDE Plasma 5.27 LTS for i686 (32-bit x86).

## Why this is possible (and why Plasma 6 is not)

Plasma 5.27 is built on **Qt 5.15 LTS + KDE Frameworks 5**, both of which
support i686. Arch Linux 32 ships the full Plasma 5.27.7 stack in its stable
`extra` repository, confirming the build is viable.

Plasma 6 / KDE Frameworks 6 require Qt 6, which dropped 32-bit support.
That wall is hard — see `packages/PACSCRIPT_FORMAT.md` for details.

## Version

**Plasma 5.27.12** — the final LTS point release (January 2025). This is a
fixed snapshot; Plasma 5.27 is in security-only maintenance mode upstream.

## Package tree (22 pacscripts)

Build order follows dependency depth — install from top to bottom.

```
plasma/
  kdecoration/            Window decoration plugin API (dep of kwin, breeze)
  libkscreen/             Screen management library (dep of kwin, kscreen)
  plasma-framework/       Plasma QML/C++ framework — libplasma (KF5 5.115.0)
  kactivitymanagerd/      Activities daemon (dep of plasma-workspace)
  kscreenlocker/          Screen locker library and greeter (dep of kwin)
  milou/                  KRunner search plugin (dep of plasma-workspace)
  kwin/                   Window manager and compositor (X11 + optional Wayland)
  kscreen/                Display configuration KCM
  plasma-workspace/       Plasmashell, notifications, logout, lockscreen
  plasma-desktop/         Desktop containment, task manager, KRunner

system/
  libksysguard/           Process/resource monitoring library
  systemsettings/         System Settings application
  kinfocenter/            System information centre
  kmenuedit/              Application menu editor
  kde-cli-tools/          kdesu, kdialog, kstart, kreadconfig5, kioclient5
  ksshaskpass/            SSH passphrase dialog with KWallet integration
  kwrited/                Wall message notification daemon
  ksystemstats/           System statistics daemon (requires libksysguard)

extras/
  breeze/                 Breeze widget style, window decoration, icons, cursors
  bluedevil/              Bluetooth integration (BlueZ 5)
  plasma-nm/              NetworkManager system tray applet
  plasma-pa/              PulseAudio volume applet
  powerdevil/             Power management (brightness, suspend, battery)
  kdeplasma-addons/       Extra widgets: calculator, notes, timer, weather, etc.
  drkonqi/                Crash handler with GDB backtrace collection
```

## Relationship to community-32bit

This overlay depends on `community-32bit` for LXQt components (which provide
Qt5 libraries and build tools). Enable both overlays together, with
`community-32bit-plasma5` at higher priority (20 vs 15).

## sha256sums

All pacscripts use `sha256sums=("SKIP")` placeholders. Run
`scripts/kport/fill-sha256.sh overlays/community-32bit-plasma5` before
enabling in production.

## Enabling this overlay

```yaml
# config/repositories.yml
- name: community-32bit-plasma5
  description: "KDE Plasma 5.27 LTS for i686"
  url: https://github.com/your-org/kport-community-32bit-plasma5
  priority: 20
  enabled: true
  auto_sync: true
```

Also enable `community-32bit` (priority 15) for the Qt5/KF5 base libraries.

## Validation

The Arch Linux 32 project ships Plasma 5.27.7 for i686 in its stable `extra`
repository (last updated August 2023). Their PKGBUILDs are the reference for
dependency lists and build flags used in these pacscripts.
