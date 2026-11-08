# Remi

A desktop pet who shows what your coding agent is doing.

She sits on your desktop — transparent, always on top — and animates to match one agent session: thinking, reading, writing, replying, proud when a turn lands. The one that matters: when the agent is **blocked waiting for your approval**, she stands there waiting, and you notice without watching the terminal.

**Claude Code and Codex are supported.** See [Harnesses](#harnesses) for compatibility and event coverage.

The session can be on this machine or on any host you already `ssh` to, and she keeps showing the right thing **while you are detached from it**.

## States

One session, nine states — eight poses, since Writing and Replying share one. Remi holds whichever state that session is in until an event moves her out of it.

|                                                              | state                      | when she shows it                                                                                                                                                            |
| ------------------------------------------------------------ | -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <img src="assets/preview/thinking.gif" width="110">          | **Thinking**               | The agent is working out what to do next — between the prompt and the first tool call, or between tool calls.                                                                |
| <img src="assets/preview/viewing.gif" width="110">           | **Viewing**                | Reading: a file read, a search, a listing. Pen in hand, on task.                                                                                                             |
| <img src="assets/preview/writing.gif" width="110">           | **Writing** · **Replying** | Changing files — an edit, a write, a patch — or putting words on your screen. Two states, deliberately one pose: a separate one would be a distinction without a difference. |
| <img src="assets/preview/waiting-for-input.gif" width="110"> | **Waiting for input**      | **Blocked on you** — a permission prompt, or a question. The state the whole pet exists for: she sits there waiting and you notice without watching the terminal.            |
| <img src="assets/preview/proud.gif" width="110">             | **Proud**                  | The turn just landed. Fades to Idle after a few seconds.                                                                                                                     |
| <img src="assets/preview/idle.gif" width="110">              | **Idle**                   | Between turns: what Proud fades into, or a turn you interrupted. Empty-handed rest.                                                                                          |
| <img src="assets/preview/background.gif" width="110">        | **Background**             | The turn ended, but work it started is still running — a background command or subagent. Idle, with her book glowing. Claude Code only.                                      |
| <img src="assets/preview/offline.gif" width="110">           | **Offline**                | No session — it ended, or the host went away. The same rest as Idle, greyed and dimmed so it reads as "nothing running" from across the room.                                |

The previews are the GIF art, downscaled. The app renders a Spine skeleton with the same poses, created by [森哈_Yeah](https://space.bilibili.com/2021405481).

## Install

Install `remi-hook` on each machine running an agent, then install the desktop app on the machine where you want to see Remi. The desktop app does not install the hook for you.

### Agent hook setup

**macOS and Linux:** run this on the machine running your agent, including a remote host if you use one:

```sh
curl -fsSL https://github.com/un-lock-able/remi-desktop/releases/latest/download/install.sh \
  | sh -s -- --harness claude-code --check
```

Replace `claude-code` with `codex` for Codex. The installer downloads the latest release binary for your platform, verifies it against `SHASUMS256.txt`, installs it to `~/.local/bin/remi-hook`, and runs `remi-hook setup` with the arguments you supplied.

**Windows:** run this in PowerShell to install and configure the hook for Codex:

```powershell
& ([scriptblock]::Create((Invoke-RestMethod `
  https://github.com/un-lock-able/remi-desktop/releases/latest/download/install.ps1))) `
  --harness codex --check
```

The Windows installer verifies the download against `SHASUMS256.txt` and installs `%USERPROFILE%\.local\bin\remi-hook.exe`. The binary is x86_64; ARM64 machines run it under emulation. Claude Code hooks currently do not work on Windows; use Codex there.

Keep a manually installed Windows binary named `remi-hook.exe` and put it in a path **without spaces**. If your user profile path contains spaces, set something like `$env:REMI_PREFIX = 'C:\remi\bin'` before running the installer. Codex's Windows hook runner cannot launch the hook from a path containing spaces.

Both scripts accept `REMI_VERSION` to select a release tag, `REMI_REPO` to download from a fork, `REMI_PREFIX` to change the installation directory, and `REMI_HOOK_BIN` to install a local binary. Keep the default `~/.local/bin` location on remote hosts: the desktop app looks for the hook there over SSH.

**After setup:** restart your agent to load the hooks. Claude Code setup merges Remi's hooks into `~/.claude/settings.json`. Codex setup merges into `$CODEX_HOME/hooks.json` (default `~/.codex/hooks.json`), preserving `config.toml` and `notify`; restart Codex, then use **`/hooks` in the CLI to review and trust the Remi hooks**. `check` verifies the configuration file, not that trust decision. Desktop and IDE clients must load the same `CODEX_HOME` configuration. Setup preserves other hooks and keeps a `.bak` of changed configuration files.

#### Basic usage

Add `~/.local/bin` to your `PATH` on macOS/Linux, or `%USERPROFILE%\.local\bin` on Windows, to run `remi-hook` by name. Otherwise, use its full installation path. The installed hooks already use the full path.

```sh
remi-hook setup --harness claude-code --check  # Configure Claude Code; safe to run again
remi-hook setup --harness codex --check        # Configure Codex on the same machine
remi-hook check --harness codex                # Check the installed hooks and state directory
remi-hook snapshot                            # Print current session records as JSON
remi-hook uninstall --harness codex            # Remove Remi's hooks for this harness
```

Run setup once for each harness you use. `setup`, `check`, and `uninstall` require an explicit `--harness`; use either `claude-code` or `codex`. `uninstall` removes the selected harness's Remi hooks; the binary and session state remain installed.

Once configured, the hook runs automatically as your agent works. Start an agent session and select it in Remi's tray or right-click menu.

### Desktop app

Download the package for your platform from the [latest release](https://github.com/un-lock-able/remi-desktop/releases/latest). The desktop app runs on the machine displaying the pet; it can follow local sessions or sessions on a host you connect to over SSH.

| Platform | Package and installation |
| --- | --- |
| macOS 11+ (Intel and Apple Silicon) | Download `Remi-*-macos-universal.app.tar.gz`, unpack it, and move `Remi.app` to `/Applications`. Run `xattr -dr com.apple.quarantine /Applications/Remi.app` before opening it. |
| Windows 10/11 | Download and run `Remi-*-windows-x86_64.msi` or `Remi-*-windows-x86_64-setup.exe`. If SmartScreen warns, select **More info → Run anyway**. |
| Linux x86_64 | Download `Remi-*-linux-x86_64.deb` or `.AppImage`. Install the Debian package with `sudo apt install ./Remi-*-linux-x86_64.deb`, or make the AppImage executable with `chmod +x` and run it. |

The macOS and Windows builds are not code-signed, so the commands and prompts above are needed on first launch.

Remi has **no Dock icon** on macOS. Use the tray icon or right-click her for the session menu — pick a session, connect to a host, resize, hide, quit. For a remote session, install the hook on that host first and use your existing SSH configuration to connect from Remi's menu.

#### Linux

Remi uses **native Wayland** when it is available and falls back to X11 otherwise. An explicit `GDK_BACKEND` overrides this choice, for example `GDK_BACKEND=x11 remi-desktop` to run under XWayland, which allows position restoration and always-on-top requests.

Native Wayland still leaves positioning, stacking and taskbar visibility to the compositor. On KDE Plasma, add a window rule (System Settings → Window Management → Window Rules) matching Remi's window class:

| property                        | setting               |
| ------------------------------- | --------------------- |
| Position                        | Remember              |
| Keep above other windows        | Apply initially · Yes |
| Skip taskbar / pager / switcher | Apply initially · Yes |

The tray needs AppIndicator (`libayatana-appindicator3-1` on Debian/Ubuntu, `libayatana-appindicator` on Arch). KDE Plasma shows it natively; GNOME needs its AppIndicator extension. Right-clicking the pet also opens the menu.

`Remi-*-linux-x86_64.deb` and `.AppImage` are the pet as macOS and Windows ship her: Spine only. WebKitGTK does not always composite the transparent WebGL canvas that renderer draws into, and a pet that fails that way is invisible rather than merely ugly — she says so in a message on the window, but there is nothing to see. If that happens, install the `-gif-fallback` package instead: the same build plus 8.5 MiB of GIF art the renderer falls back to. The feature is off by default, so a local build has no GIF art unless you pass `--features gif-fallback` yourself.

### Building from source

Install Rust and your platform's native build tools. To build the desktop app, macOS needs Xcode Command Line Tools; Windows needs MSVC C++ build tools and WebView2.

Clone the repository, then run the commands below from its root:

```sh
git clone https://github.com/un-lock-able/remi-desktop.git
cd remi-desktop
```

Linux needs Rust, a C/C++ build toolchain, GTK 3, WebKitGTK 4.1 and AppIndicator development packages. On Debian/Ubuntu:

```sh
sudo apt install build-essential pkg-config libwebkit2gtk-4.1-dev \
  libayatana-appindicator3-dev librsvg2-dev patchelf
```

On Arch: `sudo pacman -S --needed base-devel rust pkgconf webkit2gtk-4.1 libayatana-appindicator librsvg patchelf`.

```sh
cargo test --workspace          # all three crates
cargo run -p remi-desktop       # the pet, straight from cargo — no node, no tauri CLI needed
cargo build -p remi-hook --release
```

To install the hook from the checkout on macOS/Linux, use `--root ~/.local`: Cargo adds the `bin` directory itself, placing the binary at the same path as the release installer.

```sh
cargo install --path crates/remi-hook --locked --root ~/.local
~/.local/bin/remi-hook setup --harness claude-code --check
# or: ~/.local/bin/remi-hook setup --harness codex --check
```

On Windows, install and configure the hook from the checkout in PowerShell:

```powershell
cargo install --path crates/remi-hook --locked --root "$env:USERPROFILE\.local"
& "$env:USERPROFILE\.local\bin\remi-hook.exe" setup --harness codex --check
```

The Windows installation path must still contain no spaces. If needed, use `--root C:\remi` and run `C:\remi\bin\remi-hook.exe` instead. Restart your agent and complete the hook setup steps above after installing from source too.

The frontend has **no build step**: static files and ES modules under `crates/remi-desktop/ui/`, with `spine-webgl` vendored. `build.rs` stages the Spine art into `ui/assets/` on every build.

To bundle the desktop app, install the Tauri CLI and build from `crates/remi-desktop`. Choose the build command for your platform:

```sh
cargo install tauri-cli --version "^2.11" --locked
cd crates/remi-desktop
cargo tauri build --bundles app                            # macOS
# cargo tauri build --bundles msi,nsis                     # Windows
# cargo tauri build --bundles deb,appimage                 # Linux
# cargo tauri build --bundles deb,appimage --features gif-fallback
```

On macOS, bundling also merges `Info.plist`, which makes the app Dock-less. `cargo run` does not, so the development build has a Dock icon.

## Harnesses

Remi labels sessions by harness, so Claude Code and Codex can run on the same machine without mixing their sessions.

| Harness | Support |
| --- | --- |
| **Claude Code** | Supported on macOS/Linux through hooks in `settings.json`. Includes background work tracking. Hooks currently do not work on Windows. |
| **Codex** | Supported through lifecycle hooks in `hooks.json`, including on Windows. Requires a Codex runtime with lifecycle-hook support and trusted hooks. Reply streaming and arbitrary shell-command classification are unavailable through this adapter. |
| **OpenCode** | Planned; the plugin is not implemented yet. |

See [Agent hook setup](#agent-hook-setup) for installation. The [implementation plan](docs/IMPLEMENTATION-PLAN.md) and [project brief](docs/PROJECT-BRIEF.md) cover the design and development decisions.

## License

The **code** is MIT — see `LICENSE`.

The character art is **not covered by that license**. The character is from [_Zenless Zone Zero_](https://zenless.hoyoverse.com/); the GIFs and the Spine skeleton are by [森哈_Yeah](https://space.bilibili.com/2021405481) on bilibili. It is **personal, non-commercial use only** — see `assets/README.md`.

Remi is an unofficial fan project, **not affiliated with or endorsed by miHoYo / HoYoverse**. It sells nothing and accepts no payment.
