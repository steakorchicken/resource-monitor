# Resource Monitor — Implementation Plan

A native macOS resource monitor in the spirit of Windows Task Manager's **Performance** tab, plus a read-only process list, a menu-bar mode, and extras (GPU, sensors, battery, alerts). Sleek, always-dark UI.

This document is the hand-off spec. Build it phase by phase; each phase should compile and run before moving on.

---

## 1. Fixed decisions

| Topic | Decision |
|---|---|
| Platform | macOS only. Deployment target **macOS 14** (needed for `@Observable`). Dev machine: macOS 27, Apple M1 (4 P-cores + 4 E-cores), 8 GB RAM, has a battery. |
| Language / UI | Swift + SwiftUI + Swift Charts. AppKit only where SwiftUI can't do it (dock-icon toggle, window activation). |
| Toolchain | **Command Line Tools only, no Xcode.** Build with Swift Package Manager (`swift build`). No `.xcodeproj`, no SwiftUI previews, no asset catalogs. |
| Tests | **Swift Testing** (`import Testing`), which is available in the CLT. XCTest is not available. |
| Window modes | Main window **and** a `MenuBarExtra`; each can be toggled in Settings, but at least one must stay enabled. |
| Processes | Sortable, searchable list. **View only: no kill or end action anywhere.** |
| History | 60 samples at a 1 s interval (60 s window). The interval can be set to 0.5 s, 1 s or 2 s in Settings; the history always holds 60 samples. |
| Theme | Always dark (`.preferredColorScheme(.dark)` and `NSApp.appearance = .darkAqua`). |
| Privileges | No root, no helper tools, no network calls, nothing stored except `UserDefaults` settings. |
| Bundle ID | `com.julianmarin.ResourceMonitor`, app name **Resource Monitor**. |

---

## 2. Project layout

```
Resource Monitor/
├── Package.swift
├── PLAN.md
├── README.md                     (how to build/run, written in Phase 7)
├── scripts/
│   └── build-app.sh              (packages the binary into "Resource Monitor.app")
├── Resources/
│   └── Info.plist
├── Sources/
│   ├── MonitorCore/              (library: no SwiftUI, only Foundation, Darwin, IOKit)
│   │   ├── Models/               (CPUSample, MemorySample, DiskSample, NetworkSample,
│   │   │                          GPUSample, SensorSample, BatterySample, ProcessInfoRow, SystemInfo)
│   │   ├── Readers/              (CPUReader, MemoryReader, DiskReader, NetworkReader,
│   │   │                          GPUReader, SensorReader, BatteryReader, ProcessReader, SystemInfoReader)
│   │   ├── History/RingBuffer.swift
│   │   └── Format/ByteFormatter.swift, RateFormatter.swift, DurationFormatter.swift
│   └── ResourceMonitor/          (executable: SwiftUI app)
│       ├── ResourceMonitorApp.swift
│       ├── MonitorStore.swift    (@Observable @MainActor; owns the sampling loop and histories)
│       ├── AlertManager.swift
│       ├── Settings/AppSettings.swift, SettingsView.swift
│       ├── Theme/Theme.swift
│       ├── Components/           (SparklineView, LiveChartView, StatTile, UsageBar, SectionCard, PressureGauge)
│       ├── Sidebar/SidebarView.swift
│       ├── Detail/               (CPUDetailView, MemoryDetailView, DiskDetailView, NetworkDetailView,
│       │                          GPUDetailView, SensorsDetailView, BatteryDetailView)
│       ├── Processes/ProcessListView.swift
│       └── MenuBar/MenuBarLabel.swift, MenuBarPanel.swift
└── Tests/
    └── MonitorCoreTests/         (Swift Testing)
```

`Package.swift`: `swift-tools-version:6.0`, platform `.macOS(.v14)`, targets `MonitorCore` (library), `ResourceMonitor` (executable, depends on MonitorCore), and `MonitorCoreTests`. Set `swiftLanguageModes: [.v5]` to avoid strict-concurrency friction with C APIs; keep all UI state on `@MainActor`. Link `IOKit` with `linkerSettings: [.linkedFramework("IOKit")]`.

---

## 3. Data sources (macOS APIs)

All readers are plain `final class`es that keep the previous raw counters and return a sample built from deltas. They return `nil` or empty values when data is unavailable; **they never crash and never fatalError**. Each sample carries a `timestamp` (use `ContinuousClock` or `mach_absolute_time`), and rates are computed from the real elapsed time, not the nominal interval.

### CPU (`CPUReader`)
- Per-core ticks: `host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, …)` gives user/system/idle/nice ticks per core. Usage = Δ(user+system+nice) / Δ(total). **`vm_deallocate` the returned array every call** (otherwise it leaks).
- Total = the average across cores, also split into user % and system %.
- Core types: `sysctl hw.perflevel0.logicalcpu` (Performance) and `hw.perflevel1.logicalcpu` (Efficiency). On Apple Silicon the E-cores have the **lowest** indices (M1: cores 0–3 = E, 4–7 = P). Label them that way; fall back to "Core N" if the perflevel sysctls are missing.
- Load average: `getloadavg`. Uptime: `sysctl kern.boottime`. Chip name: `machdep.cpu.brand_string`.
- Process and thread counts: taken from `ProcessReader`'s latest pass (sum of `pti_threadnum`).
- No CPU frequency (no public API on Apple Silicon). Don't fake it.

### Memory (`MemoryReader`)
- `host_statistics64(…, HOST_VM_INFO64, …)` into `vm_statistics64`; page size from `vm_kernel_page_size`.
- Use Activity Monitor's definitions:
  - **App** = (internal_page_count − purgeable_count) × page
  - **Wired** = wire_count × page
  - **Compressed** = compressor_page_count × page
  - **Cached files** = (external_page_count + purgeable_count) × page
  - **Used** = App + Wired + Compressed
  - **Total** = `sysctl hw.memsize`
- Pressure: `sysctl kern.memorystatus_vm_pressure_level` (1 = normal/green, 2 = warning/yellow, 4 = critical/red).
- Swap: `sysctl vm.swapusage` into `xsw_usage` (total, used).

### Disk (`DiskReader`)
- I/O: iterate `IOServiceMatching("IOBlockStorageDriver")` and read the `"Statistics"` dictionary: `"Bytes (Read)"`, `"Bytes (Write)"`, `"Operations (Read)"`, `"Operations (Write)"`. Sum across drivers and take deltas to get read/write bytes per second and IOPS. Release IOKit objects with `IOObjectRelease`.
- Volumes: `FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys:options: [.skipHiddenVolumes])` with `.volumeNameKey`, `.volumeTotalCapacityKey`, `.volumeAvailableCapacityForImportantUsageKey`, `.volumeIsInternalKey`, `.volumeIsRemovableKey`. Refresh the volume list every 10 s, not every tick.
- "Active time %" (like Windows) isn't available. Leave it out.

### Network (`NetworkReader`)
- Counters: use `sysctl` with `[CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]` and walk the `if_msghdr2` records to read the **64-bit** `ifm_data.ifi_ibytes` / `ifi_obytes`. (`getifaddrs` uses 32-bit counters that wrap, so don't use it for byte counts.)
- Addresses: `getifaddrs` for the IPv4/IPv6 addresses of each interface (`freeifaddrs` afterwards).
- Show physical interfaces (`en*`) individually. The **total** rate excludes `lo0`, `utun*`, `awdl*`, `llw*`, `bridge*`, `anpi*`, `ap*`, `gif*` and `stf*`.
- Handle counter resets (interface goes down): if the delta is negative, treat it as 0.
- Also keep session totals (bytes sent/received since the app launched).
- Wi-Fi SSID needs Location permission. **Skip it**; show the interface name and type only.

### GPU (`GPUReader`) — extra
- `IOServiceMatching("IOAccelerator")` → `IORegistryEntryCreateCFProperty(…, "PerformanceStatistics")` → `"Device Utilization %"`, `"Renderer Utilization %"`, `"Tiler Utilization %"`, `"In use system memory"`. Confirmed working on this Mac. The GPU model name comes from the `"model"` property, with a fallback to the chip name.

### Sensors (`SensorReader`) — extra, best-effort
- Read temperatures and fans from the SMC via IOKit (`AppleSMC` service, `IOConnectCallStructMethod` with selector 2, the standard `SMCKeyData_t` struct). Fans: key `FNum` gives the count; `F%dAc` is the current RPM, `F%dMn`/`F%dMx` are min/max. Temperatures on Apple Silicon: probe a candidate list (`Tp01`, `Tp05`, `Tp09`, `Tp0D`, `Tp0T`, `Tg05`, `Tg0D`, `Ts0P`, `TB0T`, …) and keep the keys that return a plausible value (10–120 °C, type `flt `). Group them into "CPU", "GPU", "Battery" and "Other"; show the CPU average and max.
- The M1 MacBook Air has **no fan**. If `FNum` is 0 or missing, hide the fan card.
- If the SMC can't be opened or no keys are valid, the Sensors section shows "Sensor data not available on this Mac" instead of failing. **Don't use private frameworks** (no `IOHIDEventSystemClient`).

### Battery (`BatteryReader`) — extra
- `IOPSCopyPowerSourcesInfo` / `IOPSCopyPowerSourcesList` / `IOPSGetPowerSourceDescription` for: charge %, charging state, power source, and time remaining.
- `IOServiceMatching("AppleSmartBattery")` properties for `CycleCount`, `AppleRawMaxCapacity` (or `NominalChargeCapacity`) vs `DesignCapacity` (health %), `Temperature` (in 0.01 °C), `Voltage`, `Amperage` (to compute watts).
- If the Mac has no battery, the whole Battery section is hidden.

### Processes (`ProcessReader`)
- PIDs: `proc_listallpids`. For each PID:
  - Name: `proc_name`, falling back to the last path component from `proc_pidpath`.
  - CPU and threads: `proc_pidinfo(pid, PROC_PIDTASKINFO, …)` into `proc_taskinfo` (`pti_total_user + pti_total_system` in Mach time units). Convert with `mach_timebase_info`. CPU % = Δcpu_ns / Δwall_ns × 100 (can go above 100 % across cores, like Activity Monitor).
  - Memory: `proc_pid_rusage(pid, RUSAGE_INFO_V4, …)` gives `ri_phys_footprint` (matches Activity Monitor's "Memory"), plus `ri_diskio_bytesread` / `ri_diskio_byteswritten` deltas for per-process disk rates.
  - User: `proc_pidinfo(PROC_PIDTBSDINFO)` gives `pbi_uid`; look the name up with `getpwuid` and cache it.
- Root and other users' processes often refuse `proc_pidinfo`. **Still list them** with their name, PID and user (if readable), and show "—" for metrics. Sort "—" values last.
- Compute icons lazily and cache them: `NSRunningApplication(processIdentifier:)?.icon`, falling back to an SF Symbol `gearshape`.
- Process sampling runs only while the Processes view or the CPU detail "top processes" card is visible. Otherwise it runs every 5 s, just to keep the counts current.

---

## 4. State and sampling (`MonitorStore`)

- `@Observable @MainActor final class MonitorStore`, injected through `.environment`.
- A sampling `Task` runs the readers **off the main actor** (on a dedicated serial `DispatchQueue` or a nonisolated actor), then publishes one combined `Snapshot` back to the main actor each tick, so there's a single UI update per tick.
- `RingBuffer<T>` (capacity 60) histories: CPU total, each core, memory used, swap, disk read/write, net in/out, GPU, CPU temperature.
- Latest values: current samples, the volume list, interfaces, the process list, battery and sensors.
- The sampler starts on launch and keeps running while either the window or the menu-bar panel exists (the menu-bar label needs live data). When the main window is closed **and** the menu bar is hidden, the app quits.
- Performance target: the app itself uses **under 1 % CPU** on average with the window open, and under 60 MB of memory. Check this in Activity Monitor during Phase 7.

---

## 5. UI spec

### Theme (`Theme.swift`)
- Window background `#0B0E14`; card background `#141922`; card border `#1F2633` (1 pt); primary text `#E6EAF2`; secondary text `#8A93A6`.
- Accent colors per resource:
  - CPU `#4C9AFF`
  - Memory `#B07CFF`
  - Disk `#3DDC97`
  - Network `#FFB547` (download) / `#FF7A59` (upload)
  - GPU `#2ED3E6`
  - Sensors `#FF5C7A`
  - Battery `#9BE15D`
- Status colors: green `#3DDC97`, yellow `#FFC94D`, red `#FF5C5C`.
- Fonts: SF Pro. Large numbers in `.system(size: 28, weight: .semibold, design: .rounded)` with `.monospacedDigit()` so values don't jitter.
- Cards have a 12 pt corner radius and 16 pt padding. Charts use a line with a vertical gradient area fill from accent at 35 % opacity down to 0 %, faint gridlines (`#1F2633`), and no chart animation between ticks (keep it smooth and cheap).
- Window material: dark solid background (not vibrancy). Use `.windowStyle(.hiddenTitleBar)` with a custom header, minimum window size 900×600.

### Main window
`NavigationSplitView` layout:
- **Sidebar** (about 240 pt): one row per resource, like Task Manager. Each row has the resource name, the current value as a subtitle (e.g. "23 %", "5.1 / 8 GB", "R 2 MB/s · W 0", "↓ 1.2 MB/s ↑ 80 KB/s"), and a 60-sample `SparklineView` tinted in the accent color. The order is: CPU, Memory, Disk, Network, GPU, Sensors, Battery. Below a divider is **Processes**. Hide the Sensors and Battery rows when they're unavailable.
- **Detail views** each have a header (resource name, plus the hardware name on the right, e.g. "Apple M1"), a large `LiveChartView` (60 s, x-axis labeled "60 seconds" → "0" like Windows), then a grid of `StatTile`s.
  - **CPU:** total % chart. A segmented control switches between "Overall" and "Per core". Per core is a grid of small charts labeled "P-core 1…" / "E-core 1…". Tiles: Utilization, User, System, Idle, Load avg (1/5/15), Processes, Threads, Uptime. Card: **Top 5 processes by CPU**.
  - **Memory:** used-memory chart (the y-axis is total RAM) and a **stacked composition bar** (App, Wired, Compressed, Cached, Free, each a tinted shade of purple, with a legend). Pressure gauge (green/yellow/red). Tiles: Used, Available, App, Wired, Compressed, Cached, Swap used, Total. Card: Top 5 processes by memory.
  - **Disk:** a read/write chart with two series (read = accent, write = lighter tint), auto-scaled with a readable max label. Tiles: Read speed, Write speed, Read IOPS, Write IOPS. A card per volume shows the name, a used/free `UsageBar`, "X GB free of Y GB", and an internal/external badge.
  - **Network:** a download/upload chart with two series, auto-scaled. Tiles: Download, Upload, Session received, Session sent. One card per active interface: name (en0 …), type (Wi-Fi/Ethernet, using `SCNetworkInterface` from SystemConfiguration if simple, else just the BSD name), IPv4, IPv6, and that interface's own rates.
  - **GPU:** a utilization chart. Tiles: Device %, Renderer %, Tiler %, GPU memory in use.
  - **Sensors:** a CPU temperature chart, a list of all valid sensors grouped by category with the current value in °C, and a fan card (RPM against the min/max bar) if the Mac has fans.
  - **Battery:** a large charge ring, state (Charging / On battery / Charged), time remaining, power draw (W), health %, cycle count, temperature, and power source.
- **Processes view:** a SwiftUI `Table` with sortable columns: Icon+Name, PID, User, CPU %, Memory, Threads, Disk read/s, Disk write/s. The default sort is CPU % descending. There's a search field (`.searchable`) that filters by name or PID, and a toggle for "My processes / All processes". Rows refresh in place without losing the selection or scroll position (use a stable `id = pid`). **No context menu with kill/quit.** Show a footer with the process count and thread count.

### Menu bar (`MenuBarExtra`, `.menuBarExtraStyle(.window)`)
- **Label:** compact monospaced text with optional SF Symbols, e.g. `cpu 23% · mem 64%`. Which metrics appear (CPU, Memory, Network ↓↑, GPU, Temperature) is configurable in Settings; the default is CPU + Memory. Keep the label width stable (fixed-width formatting) so the menu bar doesn't jiggle.
- **Panel** (about 320 pt wide, dark): four compact cards (CPU, Memory, Disk, Network), each with a value and a sparkline. A one-line GPU/temperature/battery row. Top 3 processes by CPU. Buttons: **Open Resource Monitor** (opens and activates the main window via `openWindow` + `NSApp.activate`), **Settings…**, **Quit**.

### Settings (`Settings` scene, `SettingsView`, persisted with `@AppStorage`)
- **General:** show main window at launch; show the menu-bar item; show the Dock icon (switch `NSApp.setActivationPolicy(.regular / .accessory)`); launch at login (`SMAppService.mainApp.register()`, best-effort: if it throws, show the error inline. It may need the app to live in /Applications); update interval (0.5 / 1 / 2 s).
- **Menu bar:** checkboxes for the label metrics.
- **Alerts:** an enable toggle for each, with thresholds:
  - CPU above X % for N s (default 90 %, 30 s)
  - Memory pressure reaches Warning or Critical (default: Critical)
  - Any volume above X % full (default 90 %)
  - CPU temperature above X °C (default 95)
  - Battery below X % while discharging (default 15 %)
- Guard: the "show menu bar" and "show Dock icon/window" options can't both be turned off.

### Alerts (`AlertManager`)
- Evaluates every tick against the settings. Fire a notification with `UNUserNotificationCenter` (request authorization the first time an alert is enabled).
- **Cooldown of 10 minutes per alert type**, and it re-arms only after the value drops back below the threshold (hysteresis), so you don't get spammed.
- When an alert is active, the sidebar row and the menu-bar label show a small red dot.
- Notifications only work from the bundled `.app` (they need a bundle ID). When running via a bare `swift run`, skip them gracefully and log instead.

---

## 6. Build and packaging

`scripts/build-app.sh`:
1. `swift build -c release --arch arm64`
2. Create `build/Resource Monitor.app/Contents/{MacOS,Resources}`.
3. Copy the binary to `Contents/MacOS/ResourceMonitor` and `Resources/Info.plist` to `Contents/Info.plist`.
4. Generate an app icon if feasible (optional: a simple `.icns` drawn with SF Symbol `gauge.with.dots.needle.67percent` via a small Swift script and `iconutil`; skip if it's fiddly).
5. Ad-hoc sign: `codesign --force --deep --sign - "build/Resource Monitor.app"`.
6. Print the path, and how to run it with `open "build/Resource Monitor.app"`.

`Info.plist` keys: `CFBundleIdentifier` = `com.julianmarin.ResourceMonitor`, `CFBundleName` / `CFBundleDisplayName` = `Resource Monitor`, `CFBundleExecutable` = `ResourceMonitor`, `CFBundlePackageType` = `APPL`, `CFBundleShortVersionString` = `1.0.0`, `CFBundleVersion` = `1`, `LSMinimumSystemVersion` = `14.0`, `NSHighResolutionCapable` = true, `LSApplicationCategoryType` = `public.app-category.utilities`. Don't set `LSUIElement` (the Dock policy is set at runtime).

Add `.gitignore` entries for `.build/` and `build/`. Run `git init` in Phase 1.

---

## 7. Build phases (each ends with a compiling, runnable app)

1. **Scaffold:** `Package.swift`, folder structure, `RingBuffer`, formatters, `Theme`, the empty `NavigationSplitView` window in dark mode, and `build-app.sh` + `Info.plist`. Verify that `scripts/build-app.sh` produces an app that launches. Also `git init` and the first commit.
2. **Core readers:** the CPU, Memory, Disk, Network and SystemInfo readers, plus `MonitorStore` with the sampling loop. Add unit tests for `RingBuffer`, the formatters, and delta and counter-wrap math (feed in synthetic counter values). Sanity-check the numbers against Activity Monitor and `vm_stat` / `netstat -ib` / `iostat`.
3. **Main UI for the four core resources:** `SparklineView`, `LiveChartView`, `StatTile`, `UsageBar`, the sidebar, and the CPU/Memory/Disk/Network detail views.
4. **Processes:** `ProcessReader`, the Processes table (sorting, search, my/all filter), and the top-N cards in the CPU and Memory views.
5. **Extras:** the GPU, Battery and Sensors readers and their views (Sensors last, being best-effort).
6. **Menu bar and settings:** `MenuBarExtra` label and panel, the Settings scene, the Dock-icon toggle, launch at login, the update interval, and `AlertManager` with notifications.
7. **Polish and verify:** check the app's own CPU and memory use against the targets in §4, check for leaks (watch the process memory over 10 min), handle edge cases (unplugging an external drive, Wi-Fi off, no battery), write the README, and run a final `build-app.sh`.

## 8. Definition of done
- `swift build` and `swift test` both pass with no warnings in `MonitorCore`.
- The `.app` launches from Finder, shows live data for all sections, and the values roughly match Activity Monitor.
- The menu-bar item works with the main window closed; the Dock icon toggle works.
- The process list sorts by every column and filters by search; there is no way to kill a process.
- Alerts fire (test by temporarily lowering a threshold) and respect the cooldown.
- The app uses under 1 % CPU on average and under 60 MB of memory while idle with the window open.
