# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Barik is a lightweight macOS menu bar replacement written in SwiftUI that integrates with window managers (yabai/AeroSpace). It's a personal fork focused on event-driven updates, sleep/wake handling, and custom widgets.

## Build Commands

```sh
# Build the project
xcodebuild -scheme Barik -configuration Release build

# Build for local installation
./scripts/install.sh

# Open in Xcode
open Barik.xcodeproj
```

The project has no formal test suite - use SwiftUI Previews for component testing.

## Configuration

- Config file: `~/.barik-config.toml` or `~/.config/barik/config.toml`
- Example configs: `example/` directory
- Config auto-creates with defaults if missing
- Live reloading via file system watch (DispatchSourceFileSystemObject)

## Architecture Overview

### Application Structure

Barik uses a dual-panel window system:

1. **Background Panel** (level: `desktopWindow`) - Displays blur/background
2. **Menu Bar Panel** (level: `backstopMenu`) - Displays widgets and popups

Both panels are non-activating, transparent, and appear on all spaces.

**Entry points:**
- `Barik/BarikApp.swift` - Main app struct, delegates to AppDelegate
- `Barik/AppDelegate.swift` - Handles lifecycle, panel setup, config errors, version checking

### Widget System

**Widget Registration:**
Widgets are registered in `Barik/Views/MenuBarView.swift` via a switch statement in `buildView()`. To add a new widget:

1. Add case to switch in `MenuBarView.buildView()`
2. Follow the widget pattern (see below)
3. Add config schema to `Config/ConfigModels.swift` if needed
4. Update README with widget description

**Widget Pattern:**
```swift
struct [Name]Widget: View {
    @EnvironmentObject var configProvider: ConfigProvider  // Config injection
    @ObservedObject private var manager = [Name]Manager.shared  // Singleton manager
    @State private var rect: CGRect  // For popup positioning

    var body: some View {
        // Widget UI here
        .experimentalConfiguration(cornerRadius: 15)  // Optional styling
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "[name]") {
                [Name]Popup()  // Optional popup view
            }
        }
    }
}
```

**Widget Types:**
- **Simple:** Single icon, minimal state (Caffeinate, Network)
- **Data:** Real-time data with manager classes (Battery, Time)
- **Complex:** Multi-component with ViewModels (Spaces)

### Configuration System

**Files:**
- `Config/ConfigManager.swift` - Singleton that loads/watches TOML config
- `Config/ConfigModels.swift` - Decodable structures and TOMLValue enum

**Access pattern:**
```swift
@EnvironmentObject var configProvider: ConfigProvider
let config = configProvider.resolvedConfig(widgetId: "default.battery")
let showPercentage = config["show-percentage"]?.boolValue ?? true
```

Config supports inline overrides:
```toml
displayed = [
    "default.battery",  # Uses global config
    { "default.time" = { time-zone = "America/Los_Angeles" } }  # Inline override
]
```

### Key Utilities

**DisplayManager** (`Utils/DisplayManager.swift`):
- Detects built-in display vs external monitor
- Detects notch via safe area insets
- Used to hide titles on notched displays

**SleepWakeManager** (`Utils/SleepWakeManager.swift`):
- Observes NSWorkspace sleep/wake notifications
- Posts custom notifications for widgets to pause/resume background tasks
- Used by SpacesViewModel, CalendarManager, etc.

**ImageCache** (`Utils/ImageCache.swift`):
- Caches app icons via NSCache
- Populated during window model decoding

### Window Manager Integration

**Provider Pattern** (`Widgets/Spaces/`):
The Spaces widget uses type-erased providers for yabai/AeroSpace:

```
Protocol: SpacesProvider (associatedtype SpaceType)
    ├── YabaiSpacesProvider (Widgets/Spaces/Yabai/)
    └── AerospaceSpacesProvider (Widgets/Spaces/Aerospace/)
Type Erasure: AnySpacesProvider wraps either provider
Unified Models: AnySpace, AnyWindow
```

**Update mechanisms:**
- **Yabai:** Event-driven via Darwin notifications (`com.barik.space_changed`, `com.barik.window_changed`) + 0.5s fallback polling
- **AeroSpace:** Polling only (0.5s timer)

Setup Darwin notifications for yabai signals:
```sh
# In yabairc:
yabai -m signal --add event=space_changed action="notifyutil -p com.barik.space_changed"
yabai -m signal --add event=window_created action="notifyutil -p com.barik.window_changed"
# etc...
```

### MenuBarPopup System

**Files:**
- `MenuBarPopup/MenuBarPopup.swift` - Singleton panel management
- `MenuBarPopup/MenuBarPopupView.swift` - Content wrapper with animations

**Pattern:**
Single modal HidingPanel (NSPanel subclass) reused for all popups. Content updates dynamically per widget.

**Animation flow:**
1. `MenuBarPopup.show(rect:id:content:)` posts `.willShowWindow` notification
2. `MenuBarPopupView` listens and animates in (scale 0.2→1.0, fade in, blur out)
3. Auto-hides after 350ms of no interaction
4. `.willHideWindow` notification triggers hide animation

**Positioning:**
`MenuBarPopupVariantView.computedOffset` keeps popup within screen bounds based on widget rect.

## Development Patterns

### Manager Pattern
Most data-driven widgets use singleton managers:
```swift
class BatteryManager: ObservableObject {
    static let shared = BatteryManager()
    @Published var batteryLevel: Double = 0.0

    private init() {
        // Setup IOKit notifications, timers, etc.
    }
}
```

Common managers:
- `BatteryManager` - IOKit power notifications
- `CalendarManager` - EventKit queries + polling
- `NowPlayingManager` - MPRemoteCommandCenter observations
- `SpotifyManager` - AppleScript Spotify integration
- `TelegramManager` - Telegram Desktop badge monitoring via Accessibility APIs
- `AudioOutputManager` - CoreAudio device enumeration

### State Management
- `@Published` in ObservableObject managers for reactive updates
- `@State` for transient UI state (popup rect, animation values)
- `@EnvironmentObject` for dependency injection (ConfigProvider)

### Sleep/Wake Awareness
Widgets that poll or use background tasks should observe SleepWakeManager:

```swift
NotificationCenter.default.addObserver(
    forName: SleepWakeManager.willSleepNotification,
    object: nil,
    queue: .main
) { _ in
    // Pause timers, cancel tasks
}

NotificationCenter.default.addObserver(
    forName: SleepWakeManager.didWakeNotification,
    object: nil,
    queue: .main
) { _ in
    // Resume timers, refresh data
}
```

## Widget-Specific Notes

### Spaces Widget (`Widgets/Spaces/`)
- Detects yabai/AeroSpace at runtime via command availability
- Filters out accessory apps and apps without proper icons
- Supports floating windows (yabai only)
- Stacking indicators for window stacks
- Event-driven updates preferred over polling

### NextMeeting Widget (`Widgets/Time+Calendar/NextMeetingWidget.swift`)
- Uses EventKit for calendar access
- Filters to events with attendees or meeting links (`only-meetings` config)
- Respects per-widget `show-events` configuration

### Spotify Widget (`Widgets/Spotify/`)
- AppleScript integration with native Spotify app
- 0.5s polling with sleep/wake optimization
- Album artwork loading from Spotify API (cached)
- Playback controls: play, pause, previous, next, seek
- Vertical and horizontal popup variants
- Graceful fallback when Spotify not running

### Telegram Widget (`Widgets/Telegram/`)
- Monitors Telegram Desktop (cross-platform Qt/C++ client) dock badge for unread count
- Uses Accessibility APIs (AXUIElement) to read dock badge label
- Requires accessibility permissions to be granted to Barik
- 10s polling interval with sleep/wake optimization
- Color-coded states: green (no unread), orange (1-9), red (10+)
- Works with both Telegram Desktop (`com.tdesktop.Telegram`) and native macOS Telegram (`ru.keepcoder.Telegram`)
- Opens Telegram via app activation or URL scheme
- Note: Direct database access not used due to Telegram Desktop's encrypted tdata format

### Caffeinate Widget (`Widgets/Caffeinate/`)
- Uses IOKit power assertions (`kIOPMAssertionTypePreventUserIdleSystemSleep`)
- Allows display sleep while preventing system sleep
- See [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake) for similar implementation

## File Organization

```
Barik/
├── BarikApp.swift              # Main entry point
├── AppDelegate.swift           # App lifecycle
├── Constants.swift             # App-wide constants
├── Config/                     # Configuration system
│   ├── ConfigManager.swift
│   └── ConfigModels.swift
├── Utils/                      # Shared utilities
│   ├── DisplayManager.swift
│   ├── SleepWakeManager.swift
│   ├── ImageCache.swift
│   └── VersionChecker.swift
├── Views/                      # Core views
│   ├── MenuBarView.swift       # Widget registration
│   └── BackgroundView.swift
├── MenuBarPopup/               # Popup system
│   ├── MenuBarPopup.swift
│   ├── MenuBarPopupView.swift
│   └── MenuBarPopupVariantView.swift
└── Widgets/                    # Widget implementations
    ├── Audio/                  # AudioOutput widget
    ├── Battery/                # Battery widget
    ├── Caffeinate/             # Caffeinate widget
    ├── Network/                # Network status
    ├── NowPlaying/             # Music control
    ├── Spotify/                # Spotify playback control
    ├── Telegram/               # Telegram unread tracker
    ├── Spaces/                 # Workspace/window manager
    │   ├── Yabai/
    │   └── Aerospace/
    ├── System/                 # System settings
    ├── SystemBanner/           # Update/changelog banners
    └── Time+Calendar/          # Time, calendar, meetings
```

## Common Tasks

### Adding a new widget
1. Create widget directory in `Barik/Widgets/[WidgetName]/`
2. Create `[WidgetName]Widget.swift` following widget pattern
3. Create `[WidgetName]Manager.swift` if needs background data
4. Optionally create `[WidgetName]Popup.swift` for popup view
5. Register in `MenuBarView.buildView()` switch statement
6. Add config schema to `ConfigModels.swift` if needed
7. Update README widgets table

### Debugging window manager integration
- Check yabai signals: `yabai -m query --spaces --space`
- Monitor Darwin notifications: `notifyutil -1 com.barik.space_changed`
- Check AeroSpace: `aerospace list-workspaces --json`
- SpacesViewModel logs errors to console

### Modifying appearance
- Experimental config: `[experimental.background]` and `[experimental.foreground]`
- Widget-level styling: `.experimentalConfiguration(cornerRadius:)` modifier
- Colors defined in Assets.xcassets (supports light/dark themes)
- Typography: 13pt SF Pro, medium weight (matches macOS menu bar)

## Dependencies

The project uses Swift Package Manager dependencies (defined in Xcode project):
- TOMLKit (TOML parsing)
- MarkdownUI (Changelog rendering)

All other functionality uses native macOS frameworks:
- SwiftUI (UI)
- AppKit (NSPanel, NSWorkspace)
- IOKit (Power management, battery)
- EventKit (Calendar)
- Network.framework (Network status)
- CoreAudio (Audio devices)
