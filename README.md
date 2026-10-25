# LunaDash Shell

The desktop interface of LunaDash: panel, dock, launcher, dashboard, notifications, lock
screen and settings. It is written entirely in [Slint](https://slint.dev) and runs on
[SlintLu](https://github.com/LunaDashWM/SlintLu), which turns Slint files into Wayland
layer-shell windows and provides the desktop services (audio, network, notifications, MPRIS,
tray, polkit, PAM, idle, clipboard, …). There is no C++, QML or JavaScript in this repository.

It works best on the LunaDash compositor, which starts it as the session shell and sends it
keyboard shortcuts (launcher, settings, wallpaper picker, power menu, …). On LunaDash the
wallpaper and the language are the desktop's own: choosing them in the shell changes them for
LunaDash, and changes made in LunaDash show up in the shell. It also runs on niri, Hyprland and
Sway, where it keeps its own settings.

## Features

- **Top panel** — workspaces, power, focused window, launcher / dashboard / settings
  buttons, clock with calendar, tray, clipboard history, network, Bluetooth, volume, battery
  and notifications.
- **Dashboard** — overview, media player, per-core performance and notification history, with
  quick toggles (Wi-Fi, Bluetooth, do not disturb, keep awake, dark mode) and volume /
  brightness sliders.
- **Launcher** — fuzzy search over installed applications, frequently used first; right-click
  to pin to the dock.
- **Dock** — pinned applications and open windows grouped per application; click to open,
  focus or cycle windows.
- **Wallpaper** — a picker with thumbnails for any folder and an optional desktop clock.
- **Notifications** — pop-ups with actions and images, history, do not disturb.
- **Lock screen** — PAM authentication, automatic locking after inactivity and before sleep.
- **Polkit dialog**, **power menu**, **volume / brightness OSD**, **welcome card**.
- **Settings** — appearance (mode, palettes, transparency, animations), wallpaper, panel and
  dock, notifications, power and lock, language and about.
- **Translations** — English and Traditional Chinese (`i18n/zh_TW.po`).

Settings are stored by SlintLu in `$XDG_STATE_HOME/slintlu`. The colours come from
[`theme.json`](theme.json).

## Install

```sh
git clone https://github.com/LunaDashWM/LunaDash-Shell.git
cd LunaDash-Shell
./install.sh --install-slintlu
```

This installs the shell to `~/.local/share/lunadash/shell` (or
`$XDG_DATA_HOME/lunadash/shell`) and a `lunadash-shell` launcher to `~/.local/bin`.
`--install-slintlu` builds SlintLu with `cargo` when it is not installed yet (it needs Rust and
the Wayland, xkbcommon, fontconfig and PAM development packages); without it the installer
only prints the command. When SlintLu is present, the shell is compiled with `slintlu check`
before anything is replaced.

For a system install use `sudo ./install.sh --prefix /usr`; packagers can add
`--destdir DIR`. `--dry-run` shows what would happen. To install the current `main` branch
without cloning:

```sh
curl -fsSL https://raw.githubusercontent.com/LunaDashWM/LunaDash-Shell/main/install.sh | bash -s -- --install-slintlu
```

## Run

```sh
lunadash-shell
```

Start it from your compositor's autostart, e.g. `spawn-at-startup "lunadash-shell"` in niri
or `exec lunadash-shell` in Sway / Hyprland. The shell takes over notifications, the tray and
polkit only when no other daemon provides them.

Useful commands while it runs:

```sh
slintlu msg call Shared.set-string overlay launcher   # open the launcher (also: dashboard, settings, gallery, power)
slintlu msg call Session.lock                          # lock the screen
slintlu msg call I18n.set-language zh_TW               # switch the language
```

## Develop

Run a checkout directly; SlintLu reloads it when a file changes:

```sh
slintlu --config .
```

- `slintlu check .` compiles everything and reports errors.
- `scripts/headless-check.sh` runs the shell in a private headless Sway, opens every overlay
  and popup and fails if it dies (`SHOTS=dir` keeps screenshots). CI only builds, so run
  it (and `scripts/extract-tr.py`) before pushing.
- `scripts/extract-tr.py` updates `i18n/*.po` after changing `@tr("…")` texts.
- Icons come from SlintLu's shared set (`Icon` in `@slintlu`, see SlintLu's `res/`); only the
  LunaDash mark lives here (`assets/luna.svg`).

Layout: `panel/` (panel and its popups), `dashboard/`, `launcher/`, `dock/`, `wallpaper/`,
`session/` (lock screen, power menu, polkit), `feedback/` (notifications, OSD), `settings/`,
`welcome/`, shared `components/`, `state/` (preferences and cross-window state) and `style/`.
When the shell needs something SlintLu cannot do yet, the feature is added to SlintLu.

## License

GNU General Public License v3, see [LICENSE](LICENSE).
