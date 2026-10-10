# Resource Monitor

A native macOS resource monitor in the spirit of the Windows Task Manager *Performance* tab: live CPU, memory, disk and network charts, plus GPU, sensors, battery and a read-only process list. Always dark, Swift + SwiftUI + Swift Charts, no root, no helpers, no network access.

Built for Apple Silicon on macOS 14+ using only the Command Line Tools (no Xcode).

## Install (step by step)

Resource Monitor isn't distributed as a ready-made download. You build it yourself from this source code, which takes about five minutes and never needs a paid Apple developer account. Everything runs locally; the app makes no network connections and needs no admin password.

### 1. Check that your Mac qualifies

| Requirement | What you need | How to check |
|---|---|---|
| Chip | **Apple Silicon** (M1, M2, M3, M4 or later). **Intel Macs are not supported.** | Apple menu → **About This Mac** → look for "Chip: Apple M…". If it says "Processor: Intel…", this app won't work on your Mac. |
| macOS | **macOS 14 (Sonoma) or newer** | Apple menu → **About This Mac** → the macOS version shown. |
| Developer tools | Apple's **Command Line Tools** (free, about 1 to 2 GB). A full Xcode install also works. | Step 2 below installs them. |
| Disk space | About 1 GB free for the tools, build files and the app | |
| Internet | Only for downloading the tools and this code. The app itself never goes online. | |

Tested on a MacBook with an Apple M1 running macOS 27 with Swift 6.4. It is written for macOS 14 and later and uses the Swift 6.0 toolchain or newer, but older macOS versions haven't been tried. If a build fails on yours, please open an issue and include your macOS version and the output of `swift --version`.

### 2. Install Apple's Command Line Tools

Open the **Terminal** app (press Cmd+Space, type "Terminal", press Return) and run:

```bash
xcode-select --install
```

A window appears asking to install the tools. Click **Install**, accept the license, and wait for it to finish. If Terminal says the tools are already installed, that's fine; skip ahead.

Check that you have a recent Swift:

```bash
swift --version
```

The first line should say **Swift version 6.0** or higher. If it's older, run **Software Update** in System Settings, or install the latest Command Line Tools, then check again.

### 3. Get the code

```bash
git clone https://github.com/steakorchicken/resource-monitor.git
cd resource-monitor
```

No git? It comes with the Command Line Tools from step 2. Prefer not to use git: on the repository page click **Code → Download ZIP**, unzip it, then in Terminal type `cd ` (with a trailing space), drag the unzipped folder into the Terminal window, and press Return.

### 4. Build the app

```bash
scripts/build-app.sh
```

The first build takes a minute or two and prints a lot of text. It's finished when you see:

```
Built: /…/resource-monitor/build/Resource Monitor.app
```

(You may also see harmless `ld: warning: search path … not found` lines. Ignore them.)

If it says `permission denied`, run `chmod +x scripts/build-app.sh` and try again.

### 5. Open it, or install it

To try it straight away:

```bash
open "build/Resource Monitor.app"
```

To keep it with your other apps:

```bash
cp -R "build/Resource Monitor.app" /Applications/
open "/Applications/Resource Monitor.app"
```

After that you can find it in Launchpad or Spotlight, and drag it to your Dock. Because you built the app yourself on your own Mac, macOS doesn't show the "unidentified developer" warning. If you ever do see one, right-click the app, choose **Open**, then confirm once.

### Updating

```bash
cd resource-monitor
git pull
scripts/build-app.sh
```

Quit the running app (Cmd+Q), then copy the new build over the old one with the same `cp -R` command as above.

### Uninstalling

Quit the app, drag **Resource Monitor** from Applications to the Trash, then (optional) delete the project folder. The only data it stores is a few preferences, which you can remove with `defaults delete com.julianmarin.ResourceMonitor`.

### Troubleshooting

| Problem | Fix |
|---|---|
| `xcode-select: error: command line tools are already installed` | Fine. Skip step 2's install. |
| `swift: command not found` | The Command Line Tools aren't installed. Redo step 2. |
| `error: package 'resource-monitor' is using Swift tools version 6.0.0 but the installed version is 5.x` | Your Swift is too old. Update macOS or the Command Line Tools (step 2). |
| The build fails with other errors | Open an issue with your `swift --version`, your macOS version, and the last 20 lines of output. |
| "Resource Monitor" can't be opened | Right-click it → **Open** → **Open**. Make sure you're on an Apple Silicon Mac (step 1). |
| Sensors or Battery rows are missing | Normal. They only appear when your Mac provides that data (for example, desk Macs have no battery). |
| Processes show "—" for some values | Normal. macOS doesn't let apps without admin rights read details for some system processes. |
| Launch at login won't turn on | Install the app in `/Applications` first (step 5), then try the toggle in Settings again. |

### Privacy and safety

- It only **reads** system statistics (CPU, memory, disk, network counters, GPU, temperatures, battery, process list). It has no kill or quit action for processes.
- It makes **no network connections**, collects nothing, and needs no admin password.
- The only thing it saves is a few settings in your Mac's standard preferences.

## For developers: build and run

```bash
scripts/build-app.sh
open "build/Resource Monitor.app"
```

`build-app.sh` makes a release arm64 build, wraps it in `build/Resource Monitor.app`, and ad-hoc signs it.

Other commands:

```bash
swift build                       # debug build
swift test                        # unit tests (Swift Testing)
.build/debug/ResourceMonitor --dump 3          # print raw samples to stdout and exit
open -n "build/Resource Monitor.app" --args --section memory   # open on a given section
```

## What it shows

| Section | Contents |
|---|---|
| CPU | Utilization ring and 60 s chart, user/system/idle bar, per-core view (E/P cores), load average, uptime, process and thread counts, top 5 processes |
| Memory | Used ring and chart, composition bar (App / Wired / Compressed / Cached / Free), pressure gauge, swap, top 5 processes. Uses Activity Monitor's definitions |
| Disk | Read/write chart, IOPS, a card per volume with a fill bar |
| Network | Download/upload chart, session totals, a card per active interface with addresses and rates |
| GPU | Utilization ring and chart, device / renderer / tiler engines, GPU memory in use |
| Sensors | CPU temperature chart and every temperature the SMC exposes, grouped; fans when present (best effort) |
| Battery | Charge ring, state, time remaining, power draw, health, cycles, temperature |
| Processes | Sortable table (every column), search by name or PID, My / All filter. **View only: there is no kill or quit action anywhere** |
| Settings | Update interval (0.5 / 1 / 2 s), default process filter, launch at login |

GPU, Sensors and Battery only appear in the sidebar when the Mac provides that data.

## How it works

- `Sources/MonitorCore`: a UI-free library. One reader per resource (`CPUReader`, `MemoryReader`, `DiskReader`, `NetworkReader`, `GPUReader`, `SensorReader`, `BatteryReader`, `ProcessReader`) built on Mach, sysctl, IOKit and libproc. Readers keep the previous raw counters and return rates from the real elapsed time. They return `nil` when data isn't available rather than failing. Pure delta math lives in `CounterMath.swift` and is unit-tested.
- `Sources/ResourceMonitor`: the SwiftUI app. `MonitorStore` runs the readers off the main actor once per tick, publishes one snapshot, and keeps 60-sample ring-buffer histories.
- Sampling pauses while the window is hidden or minimized, and the app quits when its window is closed.
- Process data is gathered every 2 s while a process view is on screen and every 30 s otherwise.
- Settings are stored in `UserDefaults`; nothing else is written to disk.

## Known limits

- The app icon is generated by `swift scripts/make-icon.swift` (writes `Resources/AppIcon.icns`); edit the drawing code there to change it.
- No CPU frequency or "disk active time" (no public API on Apple Silicon).
- Sensor names are SMC keys; which keys exist varies by Mac, and the CPU group reflects the SMC's CPU-related sensors, not a single die temperature.
- Processes owned by root or other users often refuse detailed queries; they are still listed, with "—" for the metrics that can't be read.
- Wi-Fi network names aren't shown (they need Location permission); interfaces appear by BSD name (`en0`).
- Launch at login can fail unless the app is in `/Applications`.
- Measured resource use of the app itself is above the original targets; see the Phase 7 notes in `PLAN.md`.

## Toolchain notes (Command Line Tools only)

- In the macOS 27 SDK `@State` is a macro whose plugin isn't in the Command Line Tools, so views use `State<T>(initialValue:)` directly. Other property wrappers are avoided for the same reason (settings use an `@Observable` class over `UserDefaults`).
- The Swift Testing macro plugin is outside the default search path, so `Package.swift` adds `-plugin-path` for the test target.
- `ld` prints harmless "search path not found" warnings about missing Xcode directories.
