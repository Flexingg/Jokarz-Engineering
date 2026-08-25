<div align="center">

# ⚙️ JOKARZ ENGINEERING ⚙️
### *Material Expressive Engineering Suite, Multi-Discipline BOM & Workshop Companion*

[![Direct Android APK Download](https://img.shields.io/badge/⬇️%20ANDROID%20APK-v1.0.0%20Release-00E5FF?style=for-the-badge&logo=android&logoColor=black)](https://github.com/Flexingg/Jokarz-Engineering/raw/main/releases/JokarzEngineering-v1.0.0.apk)
[![Direct Windows App Download](https://img.shields.io/badge/⬇️%20WINDOWS%20APP-v1.0.0%20Release-00E676?style=for-the-badge&logo=windows&logoColor=black)](https://github.com/Flexingg/Jokarz-Engineering/raw/main/releases/JokarzEngineering-Windows-v1.0.0.zip)

[![Flutter](https://img.shields.io/badge/Flutter-3.32+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.8+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android-00E676)](#)
[![Theme](https://img.shields.io/badge/Design-Material%20Expressive%20%2F%20Compose-FFB300)](#)
[![License](https://img.shields.io/badge/License-MIT-FFB300.svg)](LICENSE)
[![Release](https://img.shields.io/badge/Release-v1.0.0-00E5FF.svg)](https://github.com/Flexingg/Jokarz-Engineering/releases/tag/v1.0.0)

### 📥 **[Download Android APK (v1.0.0)](https://github.com/Flexingg/Jokarz-Engineering/raw/main/releases/JokarzEngineering-v1.0.0.apk)** | **[Download Windows App (v1.0.0 .zip)](https://github.com/Flexingg/Jokarz-Engineering/raw/main/releases/JokarzEngineering-Windows-v1.0.0.zip)**

*The ultimate multi-discipline workshop companion for makers, CAD modelers, electrical designers, machinists, and 3D printing enthusiasts.*

</div>

---

## 🎨 Material Expressive / Jetpack Compose Aesthetic

Engineered with a high-contrast industrial Cyber & Workshop dark theme:
- **Obsidian Core** (`#0B0F17` / `#131A26`): Zero eye fatigue in low-light labs and workshops.
- **Cyber Cyan Accent** (`#00E5FF`): Precision indicator for primary metrics, active navigation, and dimensional data.
- **Safety Amber Accent** (`#FFB300`): Voice recording, warnings, and power measurements.
- **Precision Emerald Accent** (`#00E676`): BOM sourcing checkmarks, tolerance fits, and passed verifications.
- **Responsive Layout**: Adaptive Navigation Rail on Windows desktop & tablets, fluid bottom NavigationBar with quick dictation FAB on mobile.

```
       ┌─────────────────────────────────────────────────────────────┐
       │                ⚙️  JOKARZ ENGINEERING HUB  ⚙️                │
       │       MATERIAL EXPRESSIVE WORKSHOP & LAB COMPANION          │
       └─────────────────────────────────────────────────────────────┘
                                       │
        ┌──────────────────────────────┼──────────────────────────────┐
        ▼                              ▼                              ▼
┌───────────────────────┐  ┌───────────────────────┐  ┌───────────────────────┐
│ 📁 PROJECTS & BOM     │  │ 🛠️ WORKBENCH TOOLS    │  │ 🎙️ FIELD VOICE NOTES  │
│ • Multi-Stage Status  │  │ • 3D Print Cost Estim.│  │ • Hands-Free Speech   │
│ • Sourcing Checklists │  │ • Tap & Clearance Drll│  │ • Live Dictation      │
│ • CSV BOM Export      │  │ • Ohm's Law & DC Power│  │ • Blueprint Photos    │
│ • CAD & Budget Stats  │  │ • Resistor Color Code │  │ • Auto-Attach to Build│
└───────────────────────┘  └───────────────────────┘  └───────────────────────┘
```

---

## 🌟 Key Features

### 1. 📁 Project Lifecycle & Bill of Materials (BOM) Manager
- Track projects across 7 engineering stages: **💡 Idea → 📐 Planning & CAD → ⚡ Prototyping → 🔬 Testing → 🏭 Production → ✅ Complete → 📦 Archived**.
- Organize by discipline: **3D Printing & CAD, Electronics & Circuits, Mechanical & Machining, Software & Embedded, Robotics, Workshop Tooling**.
- Comprehensive Bill of Materials (BOM):
  - Track part names, categories (Fasteners, Filament, Electronics, Raw Stock, Tools), supplier, SKU/part number, unit cost, and quantity.
  - Interactive procurement checklist with real-time budget vs. actual cost summation and sourcing progress bar.
  - **One-click BOM CSV Export** for procurement and purchasing spreadsheets.
- Attach workshop photos, inspection snapshots, and measurement schematics.

### 2. 🖨️ 3D Printing & Slicer Cost Estimator
- Calculate exact part production costs combining:
  - **Filament Consumption**: Spool cost and material density (PLA, PETG, ABS, TPU, Carbon Fiber PETG, ASA).
  - **Electrical Power Draw**: Printer wattage ($W$) $\times$ print duration ($h$) $\times$ local electricity rate ($\$/\text{kWh}$).
  - **Machine Depreciation**: Wear and nozzle depreciation per hour.
  - **Operator Labor**: Post-processing, prep, and design setup time.
  - **Failure & Purge Risk Buffer**: 0–30% customizable risk contingency.
- Commercial multiplier suggestions ($2\times$ and $3\times$ retail quotes).
- Direct **"Apply to Project"** integration to save estimates straight to CAD build cards.

### 3. 🔩 Fastener, Tap Drill & Clearance Hole Selector
- Searchable thread database across **Metric (M2 to M12)** and **Imperial (#2 to 1/2" UNC)**.
- Provides exact:
  - Tap drill size (mm and wire gauge / fractional inch).
  - Close clearance hole (tight fit).
  - Free clearance hole (standard fit).
  - Allen / Hex drive wrench size.

### 4. ⚡ Electronics & Circuit Solvers
- **Resistor Color Code Decoder**: Interactive 4-band and 5-band color band picker with dynamic visual resistor body rendering and automatic metric scaling ($\Omega$, $\text{k}\Omega$, $\text{M}\Omega$).
- **Ohm's Law & DC Power Solver**: Real-time cross-calculation of Voltage ($V$), Current ($I$), Resistance ($R$), and Power ($P = V \times I$).
- **LED Series Resistor Calculator**: Compute exact current-limiting resistor and minimum wattage dissipation given supply voltage ($V_s$), forward voltage ($V_f$), and LED current ($I_f$).
- **AWG Wire Gauge & Voltage Drop Calculator**: Calculate loop resistance, voltage drop, and cable power loss across standard wire sizes (10 AWG to 30 AWG) for varying amp loads and run lengths.

### 5. 📏 Dimensional Unit Converter & ISO Tolerances
- Convert between metric and imperial across **Length, Pressure, Torque, Temperature, Mass, and Power**.
- **ISO Limits & Fits Guide**: Reference standards for Hole/Shaft fits (**H7/g6 close sliding, H7/k6 locating transition, H7/p6 press fit, H11/c11 running fit**) with micron tolerances and engineering application guidelines.

### 6. 🎙️ Workshop Speech-to-Text & Field Dictation
- Hands-free voice speech-to-text logging for when working at the lathe, soldering station, or 3D printer.
- Live audio waveform pulse with automatic transcription.
- Automatically save to global lab memos or attach as timestamped engineering logs on active builds.

---

## 🛠️ Architecture & Tech Stack

- **Framework**: Flutter 3.32+ (Dart 3.8+)
- **Architecture**: Domain-Driven Layered Architecture (UI, Providers/Notifiers, Models, Services)
- **State Management**: `flutter_riverpod: ^2.6.1`
- **Navigation & Routing**: `go_router: ^13.2.5` (Stateful Shell Route with IndexedStack)
- **Speech Recognition**: `speech_to_text: ^7.4.0`
- **Camera & Photos**: `image_picker: ^1.2.1`
- **Responsive Layout**: `responsive_builder: ^0.7.1` + adaptive LayoutBuilder
- **Persistence**: Local offline JSON document store via `path_provider`
- **Formatting & IDs**: `intl: ^0.19.0`, `uuid: ^4.6.0`

```
lib/
├── main.dart                          # Entry point & ProviderScope
├── theme/
│   └── app_theme.dart                 # Material Expressive tokens & Compose palette
├── models/
│   ├── project.dart                   # Project domain model & status phases
│   ├── bom_item.dart                  # Bill of materials item & categories
│   ├── project_log.dart               # Engineering history & log entries
│   ├── voice_note.dart                # Voice dictation & transcript model
│   ├── filament_profile.dart          # 3D printer material density profiles
│   └── bolt_spec.dart                 # Fastener & tap drill database
├── services/
│   ├── storage_service.dart           # Offline JSON persistence & CSV exporter
│   └── speech_service.dart            # Speech-to-text workshop engine
├── providers/
│   ├── project_provider.dart          # Riverpod state notifier for projects & logs
│   ├── tools_provider.dart            # Calculators, estimators & fastener state
│   └── theme_provider.dart            # Dark/Light theme mode notifier
├── router/
│   └── app_router.dart                # GoRouter shell & routes
└── ui/
    ├── widgets/
    │   ├── expressive_card.dart       # Squircle/glowing container cards
    │   ├── expressive_badge.dart      # Category & status pill badges
    │   ├── voice_memo_modal.dart      # Pulsing speech dictation modal
    │   └── responsive_scaffold.dart   # Desktop NavigationRail & Mobile Nav
    └── screens/
        ├── dashboard_screen.dart      # Engineering HUD & quick tools
        ├── projects_screen.dart       # Searchable CAD & project cards
        ├── project_detail_screen.dart # Multi-tab BOM, CAD specs, and logs
        ├── project_edit_screen.dart   # Project creation & editor
        ├── workbench_screen.dart      # 5-in-1 Engineering calculator workbench
        ├── voice_notes_screen.dart    # Workshop voice note repository
        ├── settings_screen.dart       # Theme toggle, database JSON export
        └── calculators/
            ├── print_estimator_view.dart
            ├── fastener_chart_view.dart
            ├── electronics_view.dart
            ├── unit_converter_view.dart
            └── tolerances_view.dart
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

MIT License • Developed with pride for Randall Engineering by Jonathan Randall.
