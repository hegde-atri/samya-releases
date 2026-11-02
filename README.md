# Samaya releases

Prebuilt binaries of Samaya, a calm daily planner over plain Org files.
Everything stays in plain text files in a folder you choose, which open in
Emacs too. There is no account and no server.

## Install

On 64-bit Linux: Ubuntu 22.04, Debian 12, Fedora, Arch, or anything newer.

```sh
curl -fsSL https://git.hegdeatri.com/hegdeatri/samaya-releases/raw/branch/main/install.sh | sh
```

This checks the download's checksum, and its signature if
[minisign](https://jedisct1.github.io/minisign/) is installed, then puts
`samaya` in `~/.local/bin` and
adds it to your app menu. If the installer says `~/.local/bin` is not on your
`PATH`, open Samaya from the app menu or run `~/.local/bin/samaya`.

To install a particular version, pass it on:

```sh
curl -fsSL https://git.hegdeatri.com/hegdeatri/samaya-releases/raw/branch/main/install.sh | sh -s -- v0.1.0
```

On Windows x64, download `samaya-X.Y.Z-x86_64-windows.zip` from
[releases](https://git.hegdeatri.com/hegdeatri/samaya-releases/releases), verify
its checksum and Minisign signature, extract it, and open `samaya.exe`.
No installer or administrator access is needed. Windows instructions are in
the ZIP. The executable has no Windows publisher certificate, so Windows may
show an unknown-publisher warning. Closing the window quits; there is no
Windows tray icon yet.

## First run

1. Make a folder for your tasks, such as `~/org`. An empty one is fine.
2. In Samaya, open **Settings → Org files** and choose that folder. Each `.org`
   file in it is a channel, such as `work.org` or `health.org`; you can create
   channels from the app.
3. Plan tasks in **Today** and **Week**, then try **Focus** on one of them.

Calendars and the GitHub, Forgejo and Azure DevOps panels are optional. To
connect a Google or Outlook calendar, open **Settings → Calendars → Connect
calendar** and sign in; nothing needs setting up first.

## Add a task from anywhere

`samaya compose --window` pops the task composer up on its own, over whatever
is open, the way a launcher does. Enter adds the task to today, Escape cancels,
and clicking away puts it away with its draft kept. It starts Samaya in the
tray if it is not running yet, so it is quickest with `samaya --hidden` among
your login commands. Bind it to a key:

- **Hyprland 0.56**, in your Lua configuration. The rule floats the popup in
  the centre without a border, shadow, blur or animation:

  ```lua
  hl.bind("SUPER + N", hl.dsp.exec_cmd("samaya compose --window"))

  hl.window_rule({
      name  = "samaya-compose",
      match = { class = "^samaya-compose$" },

      float       = true,
      center      = true,
      border_size = 0,
      no_shadow   = true,
      no_blur     = true,
      no_anim     = true,
  })
  ```

  Other compositors can match the same window class, `samaya-compose`.
- **GNOME, KDE and others:** add a custom keyboard shortcut in the desktop's
  settings that runs `samaya compose --window`. Wayland desktops place the
  popup where they place new windows.
- **Windows:** right-click `samaya.exe`, choose **Create shortcut**, and move
  the shortcut into the Start menu folder: open it with Win + R and
  `shell:programs`. In the shortcut's **Properties**, add ` compose --window`
  to the end of **Target** and click **Shortcut key** to press a combination
  such as Ctrl + Alt + A.

`samaya compose` without `--window` opens the composer in Samaya's own window
instead.

## Noctalia integration

For native Noctalia 5.3.0, this repository is also a public plugin source.
Install a GUI build of Samaya 1.12.0 or later separately, and make sure
`samaya` is on Noctalia's `PATH`.

1. Open **Noctalia Settings → Plugins → Add source**.
2. Choose **Git**, name it `samaya`, and use
   `https://git.hegdeatri.com/hegdeatri/samaya-releases`.
3. Enable **Samaya**, then add its **Focus** widget through your bar's
   **Add widget** picker.

The widget shows your Focus clock and meetings, with a panel for Focus,
meeting Join, task capture and calendar sync. No local checkout or TOML
editing is required. See the [plugin guide](samaya/README.org) for settings,
CLI installation, troubleshooting and removal.

Plugin updates are published with Samaya releases. Noctalia's **Auto-update
plugins → All sources** setting includes this custom Git source; otherwise
use its **Update** action. Plugin updates and desktop app updates are separate.

## Upgrade and uninstall

Samaya checks for a new version once a day; **Settings → Update available**
updates it in place, once the release's signature checks out. Running the
install command again upgrades too. To uninstall:

```sh
rm ~/.local/bin/samaya ~/.local/share/applications/samaya.desktop \
  ~/.local/share/icons/hicolor/128x128/apps/samaya.png
```

Your Org folder is never touched.

On Windows, close Samaya and replace the extracted files to upgrade. Delete
the extracted folder to uninstall. Settings live in `%APPDATA%\samaya` and
caches in `%LOCALAPPDATA%\samaya`; credentials use Windows Credential Manager.

## NixOS

The prebuilt binary does not find its graphics libraries on NixOS by itself.
Enable `programs.nix-ld` and add `wayland`, `libxkbcommon`, `vulkan-loader`
and `libGL` to `programs.nix-ld.libraries`.

## Releases

What changed in each version is in [CHANGELOG.org](CHANGELOG.org), and in
Samaya itself under **Settings → Changelog**.

Each [release](https://git.hegdeatri.com/hegdeatri/samaya-releases/releases)
lists what changed and has a `samaya-X.Y.Z-x86_64-linux.tar.gz` holding the
`samaya` binary, its `.desktop` entry and icon. Windows builds come in
`samaya-X.Y.Z-x86_64-windows.zip`, holding `samaya.exe`. Both have SHA-256
checksums and Minisign signatures; older releases may contain only Linux.
Linux archives have signatures from 1.8.0 onward. Releases are published
automatically when a version is tagged. This repository also holds the
Noctalia plugin source and catalog used by Noctalia's plugin manager.

## Verifying a release

Releases are signed with this key, also in [minisign.pub](minisign.pub):

```
RWReXZNuxj5aplTyPD4awKxzs/sL9nlCssugg1Cd9ZbRWrwksTyfsJNe
```

```sh
minisign -V -P RWReXZNuxj5aplTyPD4awKxzs/sL9nlCssugg1Cd9ZbRWrwksTyfsJNe \
  -m samaya-X.Y.Z-x86_64-linux.tar.gz
```

For Windows, use `-m samaya-X.Y.Z-x86_64-windows.zip` with the same public
key. The `.minisig` file belongs beside its archive. The trusted comment it
prints is the archive's file name. This verifies the download's provenance;
it does not install a Windows publisher certificate.
