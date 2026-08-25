<div align="center">

# ⚙️ JOKARZ ENGINEERING ⚙️
### *Corporate Manufacturing Plant Mechanical Engineering Suite & Operations Companion*

[![Direct Android APK Download](https://img.shields.io/badge/⬇️%20ANDROID%20APK-v1.0.0%20Release-00E5FF?style=for-the-badge&logo=android&logoColor=black)](https://github.com/Flexingg/Jokarz-Engineering/raw/main/releases/JokarzEngineering-v1.0.0.apk)
[![Direct Windows App Download](https://img.shields.io/badge/⬇️%20WINDOWS%20APP-v1.0.0%20Release-00E676?style=for-the-badge&logo=windows&logoColor=black)](https://github.com/Flexingg/Jokarz-Engineering/raw/main/releases/JokarzEngineering-Windows-v1.0.0.zip)

[![Flutter](https://img.shields.io/badge/Flutter-3.32+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.8+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android-00E676)](#)
[![Theme](https://img.shields.io/badge/Design-Material%20Expressive%20%2F%20Compose-FFB300)](#)
[![License](https://img.shields.io/badge/License-MIT-FFB300.svg)](LICENSE)
[![Release](https://img.shields.io/badge/Release-v1.0.0-00E5FF.svg)](https://github.com/Flexingg/Jokarz-Engineering/releases/tag/v1.0.0)

### 📥 **[Download Android APK (v1.0.0)](https://github.com/Flexingg/Jokarz-Engineering/raw/main/releases/JokarzEngineering-v1.0.0.apk)** | **[Download Windows App (v1.0.0 .zip)](https://github.com/Flexingg/Jokarz-Engineering/raw/main/releases/JokarzEngineering-Windows-v1.0.0.zip)**

*A personal manufacturing mechanical engineering suite for corporate plant operations, tracking line maintenance, Kaizen improvements, capital projects, machine downtime tasks, purchase orders, and workshop diagnostics.*

</div>

---

## 🏭 Tailored for Corporate Plant Mechanical Engineering

Engineered specifically for plant floor mechanical engineers managing production lines, packaging cells, robotics, machining, and shutdown overhauls:

```
       ┌─────────────────────────────────────────────────────────────┐
       │                ⚙️  JOKARZ ENGINEERING HUB  ⚙️                │
       │       CORPORATE MANUFACTURING & PLANT WORKSHOP SUITE        │
       └─────────────────────────────────────────────────────────────┘
                                       │
        ┌──────────────────────────────┼──────────────────────────────┐
        ▼                              ▼                              ▼
┌───────────────────────┐  ┌───────────────────────┐  ┌───────────────────────┐
│ 📁 PROJECTS & TASKS   │  │ 📦 OPEN ORDERS TRACK  │  │ 🛠️ WORKBENCH TOOLS    │
│ • Maintenance/Kaizen  │  │ • Requisitions (PR)   │  │ • Tap & Clearance Drll│
│ • Dynamic 1..X Priority│ │ • Purchase Orders (PO)│  │ • Ohm's Law & DC Power│
│ • Custom Phase Steps  │  │ • ETA Countdown       │  │ • Resistor Color Code │
│ • Auto "Completed At" │  │ • One-Click Delivery  │  │ • ISO Fit Tolerances  │
│ • Machine/Sub-Assembly│  │ • Total Open PO Spend │  │ • Wire Gauges & AWG   │
└───────────────────────┘  └───────────────────────┘  └───────────────────────┘
```

---

## 🌟 Key Features

### 1. 📁 Project Management & Dynamic Priority Ranking
- **Minimal Required Input**: Only the **Title** is required; every other field is optional.
- **Corporate Categories**:
  - **1. Maintenance** (Default)
  - **2. Kaizen** (Continuous Improvement)
  - **3. Capital** (CapEx machinery & major upgrades)
- **Unique Dynamic Priority Ranking (1..X)**:
  - Active projects are ranked from 1 to X with strict uniqueness.
  - Moving a project from #3 to #1 automatically bumps the existing #1 to #2, and #2 to #3.
  - Completed or Cancelled projects freeze their priority as a **greyed-out lifetime record** (e.g. `Prev #1`) and exit the active 1..X queue.
- **Customizable Phase Pipeline**:
  - Standard Phases: `Idea`, `Pending`, `Installation`, `Validation`, `Complete`, `Cancelled`.
  - Add custom phases (e.g. `Fabrication`, `FAT Review`, `Vendor Quote`) that dynamically populate future project dropdowns alphabetically.
  - **Auto-Timestamped "Completed at"**: Auto-records completion timestamp when transitioning to `Complete` or `Cancelled`, and clears it if reopened.
- **Machine & Sub-Assembly Dropdowns**:
  - Auto-suggests unique machine lines (e.g., `Line 1 Filler`, `Cell 621 ABB Robot`, `Packaging Gantry 4`, `Stamping Press 2`) and sub-assemblies (`Infeed Starwheel`, `Gripper Tooling`, `Linear Actuator`).
- **Next Pending Task Banner**:
  - Highlights the immediate next bottleneck (e.g. `Pending mill downtime`, `Pending electrician review`, `Pending parts`).

### 2. 📋 Multiple Project Tasks & Downtime Scheduling
- Create multiple granular tasks within each project.
- Assign **Scheduled Dates** for shutdown or shift maintenance.
- Set **Pending Values** (`Pending parts`, `Pending email`, `Pending downtime`, `Pending vendor quote`).
- One-click task checkbox completion.

### 3. 📦 Open Purchase Orders (PO) & Requisitions (PR) Tracker
- Dedicated **Open Orders** dashboard tab tracking all undelivered plant orders.
- Order Fields:
  - **PR** (Purchase Requisition text)
  - **PO** (Purchase Order number text)
  - **Description** (Part description, vendor, specs)
  - **Price** (Numeric $\$$ spend)
  - **ETA** (Scheduled arrival date with countdown badges)
  - **Delivered** (Boolean toggle)
- Summary banner calculating total open PO spend across all plant equipment.

### 4. 🔩 Fastener, Tap Drill & Clearance Hole Selector
- Searchable thread database across **Metric (M2 to M12)** and **Imperial (#2 to 1/2" UNC)**.
- Tap drill sizes, close clearance holes, free clearance holes, and hex/Allen key drive sizes.

### 5. ⚡ Electronics & Power Calculators
- **Resistor Color Code Decoder**: Interactive 4-band and 5-band color decoder.
- **Ohm's Law & DC Power**: Solves Voltage, Current, Resistance, and Power ($P = V \times I$).
- **LED Series Resistor**: Calculates current-limiting resistor and wattage dissipation.
- **AWG Wire Gauge & Voltage Drop**: Calculates loop resistance and voltage drop for 10–30 AWG wiring.

### 6. 📏 Dimensional Unit Converter & ISO Tolerances
- Length, Pressure, Torque, Temperature, Mass, and Power converter.
- ISO hole/shaft limits and fits (H7/g6, H7/k6, H7/p6, H11/c11) with micron tolerance data.

### 7. 🎙️ Workshop Speech-to-Text & Field Dictation
- Live voice dictation modal with pulsing audio visualizer for hands-free workshop logging on the plant floor.
- Automatically saves to lab memos or attaches directly to active machines.

---

## 🛠️ Architecture & Tech Stack

- **Framework**: Flutter 3.32+ (Dart 3.8+)
- **Architecture**: Domain-Driven Layered Architecture (UI, Providers/Notifiers, Models, Services)
- **State Management**: `flutter_riverpod: ^2.6.1`
- **Navigation & Routing**: `go_router: ^13.2.5` (`StatefulShellRoute.indexedStack`)
- **Speech Recognition**: `speech_to_text: ^7.4.0`
- **Persistence**: Local offline JSON document store with seed data

```
lib/
├── main.dart                          # Entry point & ProviderScope
├── theme/
│   └── app_theme.dart                 # Material Expressive tokens & Obsidian theme
├── models/
│   ├── project.dart                   # Project domain model (Categories, Phases, Priority)
│   ├── task_item.dart                 # Multi-task domain entity (Pending reasons, Dates)
│   ├── order_item.dart                # PR / PO / Price / ETA order entity
│   ├── project_log.dart               # Engineering history & log entries
│   ├── voice_note.dart                # Voice dictation & transcript model
│   └── bolt_spec.dart                 # Fastener & tap drill database
├── services/
│   ├── storage_service.dart           # Offline JSON persistence & manufacturing seeds
│   └── speech_service.dart            # Speech-to-text workshop engine
├── providers/
│   ├── project_provider.dart          # Riverpod state notifier with 1..X priority ranking
│   ├── tools_provider.dart            # Fastener, electronics & tolerance calculators
│   └── theme_provider.dart            # Dark/Light theme mode notifier
├── router/
│   └── app_router.dart                # Stateful shell route with 6 branches
└── ui/
    ├── widgets/
    │   ├── expressive_card.dart       # Squircle/glowing container cards
    │   ├── expressive_badge.dart      # Category, priority & status pill badges
    │   ├── voice_memo_modal.dart      # Pulsing speech dictation modal
    │   └── responsive_scaffold.dart   # Desktop NavigationRail & Mobile NavigationBar
    └── screens/
        ├── dashboard_screen.dart      # Plant operations HUD & top priority feed
        ├── projects_screen.dart       # Searchable project list with category/phase filters
        ├── project_detail_screen.dart # Multi-tab tasks, orders, photos, and logs
        ├── project_edit_screen.dart   # Minimal title-only project creator & editor
        ├── open_orders_screen.dart    # Dedicated undelivered PR/PO parts tracker
        ├── workbench_screen.dart      # Engineering calculators & charts
        ├── voice_notes_screen.dart    # Workshop voice note repository
        └── settings_screen.dart       # Theme toggle, database JSON export
```

---

## 🚀 Building & Running

### Prerequisites
- Flutter SDK 3.32.0+
- Dart SDK 3.8.0+
- Android Studio / Android SDK (for Android build)
- Visual Studio with C++ Desktop Workload (for Windows build)

### Run in Debug Mode
```bash
flutter pub get
flutter run -d windows
# or for Android
flutter run -d android
```

### Run Tests & Analyzer
```bash
flutter test
dart analyze lib
```

### Build Production Releases
```bash
# Build Windows Desktop executable
flutter build windows --release

# Build Android release APK
flutter build apk --release
```

---

## 📄 License

MIT License • Developed for Randall Engineering by Jonathan Randall.
