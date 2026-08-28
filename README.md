<div align="center">

# ⚙️ JOKARZ ENGINEERING ⚙️
### *Corporate Manufacturing Plant Mechanical Engineering Suite & Workshop Companion*

[![Direct Android APK Download](https://img.shields.io/badge/⬇️%20ANDROID%20APK-v1.0.4%20Release-00E5FF?style=for-the-badge&logo=android&logoColor=black)](https://github.com/Flexingg/Jokarz-Engineering/releases/download/v1.0.4/jokarz-engineering-v1.0.4.apk)
[![Direct Windows App Download](https://img.shields.io/badge/⬇️%20WINDOWS%20APP-v1.0.4%20Release-00E676?style=for-the-badge&logo=windows&logoColor=black)](https://github.com/Flexingg/Jokarz-Engineering/releases/download/v1.0.4/jokarz-engineering-windows-v1.0.4.zip)

[![Flutter](https://img.shields.io/badge/Flutter-3.32+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.8+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android-00E676)](#)
[![Google Cloud Sync](https://img.shields.io/badge/Sync-Firebase%20Firestore-FFA000?logo=firebase&logoColor=white)](#)
[![Theme](https://img.shields.io/badge/Design-Material%20Expressive%20%2F%20Compose-FFB300)](#)
[![License](https://img.shields.io/badge/License-MIT-FFB300.svg)](LICENSE)
[![Release](https://img.shields.io/badge/Release-v1.0.4-00E5FF.svg)](https://github.com/Flexingg/Jokarz-Engineering/releases/tag/v1.0.4)

### 📥 **[Download Android APK (v1.0.4)](https://github.com/Flexingg/Jokarz-Engineering/releases/download/v1.0.4/jokarz-engineering-v1.0.4.apk)** | **[Download Windows App (v1.0.4 .zip)](https://github.com/Flexingg/Jokarz-Engineering/releases/download/v1.0.4/jokarz-engineering-windows-v1.0.4.zip)**

*A personal mechanical engineering suite for corporate plant operations, tracking line maintenance, Kaizen improvements, capital projects, machine downtime tasks, purchase orders, Google cloud synchronization across Android and Windows workstations, and workshop mechanical diagnostics.*

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
│ 📁 PROJECTS & TASKS   │  │ 📦 OPEN ORDERS TRACK  │  │ 🛠️ MECHANICAL TOOLS   │
│ • Maintenance/Kaizen  │  │ • Requisitions (PR)   │  │ • Simple Calc + Tape  │
│ • Dynamic 1..X Priority│ │ • Purchase Orders (PO)│  │ • Triangle Trig Solver│
│ • Custom Phase Steps  │  │ • ETA Countdown       │  │ • Tap Drills to M50/2"│
│ • Auto "Completed At" │  │ • One-Click Delivery  │  │ • Torque Spec Chart   │
│ • Machine/Sub-Assembly│  │ • Total Open PO Spend │  │ • Torque Solver (K·D·F│
│ • Clean Blank Slate   │  │ • Crib Arrival Alerts │  │ • Heat Shrink & Tints │
│ • In-App Help Guides  │  │ • PO Summary Metrics  │  │ • 🇯🇵 Translate Camera│
└───────────────────────┘  └───────────────────────┘  └───────────────────────┘
```

---

## 🌟 Key Mechanical Engineering Features

### 1. 📁 Project Management & Dynamic Priority Ranking
- **Minimal Required Input**: Only the **Title** is required; every other field is optional.
- **Clean Blank Slate**: Starts fresh with zero demo clutter. Help buttons (`?` / Info) guide new users through categories, priority shifting, and workflows.
- **Corporate Categories**:
  - **1. Maintenance** (Default)
  - **2. Kaizen** (Continuous Improvement)
  - **3. Capital** (CapEx machinery & major upgrades)
- **Unique Dynamic Priority Ranking (1..X)**:
  - Active projects are ranked 1 to X with strict uniqueness.
  - Moving a project to #1 automatically bumps the existing #1 to #2, #2 to #3, etc.
  - Completed or Cancelled projects freeze their priority as a **greyed-out lifetime record** (e.g. `Prev #1`) and exit the active queue.
- **Customizable Phase Pipeline & Timestamping**:
  - Standard Phases: `Idea`, `Pending`, `Installation`, `Validation`, `Complete`, `Cancelled`.
  - Add custom phases dynamically that populate future project dropdowns alphabetically.
  - Automatically stamps `completedAt` timestamp on transition to `Complete` or `Cancelled`.

### 2. 📋 Multiple Project Tasks & Downtime Scheduling
- Track multiple tasks within each project with descriptions, scheduled dates, and pending reasons (`Pending parts`, `Pending email`, `Pending downtime`, `Pending vendor quote`).

### 3. 📦 Open Purchase Orders (PO) & Requisitions (PR) Tracker
- Dedicated **Open Orders** navigation screen showing all undelivered parts across plant equipment.
- Tracks **PR** (Requisition), **PO** (Purchase Order), **Description**, **Price** ($\$$), **ETA**, and one-click delivery toggles.

### 4. 🧮 Simple Workshop Calculator
- Big tactile mechanical keypad with calculation tape history, memory functions ($M+, M-, MR, MC$), square root, powers, percentages, and copy-to-clipboard.

### 5. 📐 Triangle Trigonometry Solver
- Solves any triangle with 3 known values (SSS, SAS, ASA, AAS, Right Triangle).
- Calculates all sides, angles in degrees, area, perimeter, and renders an interactive **scaled geometric drawing canvas** with labeled vertex angles and sides!

### 6. 🔩 Standard Tap Drill & Clearance Hole Chart (Up to M50 & 2")
- **Strict Unit Consistency**: Metric gives mm tap drills and clearance holes; Imperial gives fractions, wire gauges, and decimal inches.
- Standard steps up to **M50 x 5.0** (Metric) and **2"-4.5 UNC** (Imperial).
- Includes tap drill sizes (75% thread), close clearance holes, free clearance holes, and hex/Allen key drive sizes.

### 7. 🔧 Fastener Torque Spec Chart
- Reference tightening torque table for **Metric Class 8.8, 10.9, 12.9** and **SAE Grade 2, Grade 5, Grade 8**.
- Displays both **Dry** and **Lubricated** torque specs in both **ft-lbs** and **N·m**.

### 8. ⚡ Bolt Torque & Clamp Load Solver
- Custom torque solver using $T = K \cdot D \cdot F$.
- Calculates Tensile Stress Area ($A_t$), Clamp Pre-load Force ($lbf$ / $kN$), and required torque in $ft\cdot lb$, $in\cdot lb$, and $N\cdot m$ based on bolt grade, friction factor $K$, and clamp load percentage.

### 9. 🔥 Thermal Shrink Fit & Steel Heat-Tint Oxide Indicator
- Calculates shaft/hub interference fits, thermal bore expansion ($\Delta D = D_0 \cdot \alpha \cdot \Delta T$), and hot slip assembly clearance.
- **Live Steel Tempering Oxide Color Swatch**: Visualizes the exact temper oxide color (Faint Straw $220^\circ\text{C}$, Medium Straw $245^\circ\text{C}$, Brown Bronze $265^\circ\text{C}$, Purple $285^\circ\text{C}$, Bright Cobalt Blue $305^\circ\text{C}$, Dark Navy Blue $330^\circ\text{C}$, Dull Grey $400^\circ\text{C}+$, Red Glow $550^\circ\text{C}+$).

### 10. 🇯🇵 Japanese Manufacturing Translation Camera Launcher
- One-click launcher in the workbench top bar deeplinking directly to Google Translate camera mode for instant Japanese $\rightarrow$ English machine label translation.

### 11. 📝 Field Notes & Notepad
- Replaceable notepad on navigation bar for quick workshop memos, field observations, machine measurements, and hands-free voice speech-to-text dictation.

### 12. ☁️ Google Cloud Account & Cross-Device Real-Time Sync (Android ⇄ Windows)
- One-click Google Sign-In with standard OAuth 2.0 PKCE desktop loopback flow.
- Real-time bi-directional synchronization powered by Cloud Firestore (`users/{uid}/projects` and `users/{uid}/voiceNotes`).
- Real-time updates automatically replicate between multiple Android phones and Windows PC engineering workstations.
- Full offline resilience: Work completely offline on the plant floor; changes automatically synchronize when reconnected.

### 13. 🎨 Hardhat & Gear App Icon + Maximized Functional UI
- Custom mechanical hardhat & gear icon on Android adaptive launcher and Windows taskbar/executable (`app_icon.ico`).
- Clean, focused interface maximizing screen space for plant diagnostics and project tracking with branding quietly anchored in the Settings footer.

---

## 🛠️ Tech Stack & Architecture

- **Framework**: Flutter 3.32+ (Dart 3.8+)
- **Architecture**: Domain-Driven Layered Architecture (UI, Providers/Notifiers, Models, Services)
- **State Management**: `flutter_riverpod: ^2.6.1`
- **Navigation & Routing**: `go_router: ^13.2.5` (`StatefulShellRoute.indexedStack`)
- **Cloud Backend**: Google Firebase (Firebase Auth, Cloud Firestore)
- **Speech Recognition**: `speech_to_text: ^7.4.0`
- **Deep Linking**: `url_launcher: ^6.3.2`
- **Persistence**: Local offline JSON document store + Cloud Firestore
- **Security**: RFC 7636 PKCE OAuth 2.0 with loopback callback for Windows desktop

---

## 📄 License

MIT License • Developed for Randall Engineering by Jonathan Randall.
