# ShipSwift

<div align="center">

![ShipSwift Banner](assets/banner.jpg)

**AI-native SwiftUI component library — production-ready code that LLMs can use to build real apps.**

[![Website](https://img.shields.io/badge/Website-shipswift.app-blue.svg)](https://www.shipswift.app/)
[![App Store](https://img.shields.io/badge/App_Store-Demo_App-black.svg)](https://apps.apple.com/us/app/shipswift-mcp-codebase/id6759209764)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift](https://img.shields.io/badge/Swift-5.0+-F05138.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-18.0+-000000.svg)](https://developer.apple.com/ios/)
[![Skills](https://img.shields.io/badge/Skills-Powered-8A2BE2.svg)](https://github.com/signerlabs/shipswift-skills)
[![ShipSwift MCP server](https://glama.ai/mcp/servers/signerlabs/ShipSwift/badges/score.svg)](https://glama.ai/mcp/servers/signerlabs/ShipSwift)

[Quick Start](#quick-start) · [Components](#components) · [Custom Dev — $5K, 4 weeks](#need-a-custom-app-built-we-do-that-too) · [Showcase Demos](#showcase-demos) · [Recipes](#recipes)

</div>

---

## What is ShipSwift?

One command gives your AI everything it needs — production-ready SwiftUI components, full-stack recipes, and the context to build real apps without guessing.

> **Browse every recipe live at [shipswift.app](https://www.shipswift.app/)** — searchable catalog, copy-paste source, live previews.

Download the [Showcase App](https://apps.apple.com/us/app/shipswift-mcp-codebase/id6759209764) to preview every component on your device.

---

## Need a custom app built? We do that too.

ShipSwift gets your AI 80% of the way. If you need the last 20% — your unique features, your brand, your backend — wired up by the people who wrote the recipes, **we ship it for you**.

| | |
|---|---|
| ⚡ **48-hour demo** | Working prototype on your TestFlight within 2 days of brief |
| 🚀 **4-week delivery** | Production-ready iOS app, App Store-submission ready |
| 💵 **From $5,000** | Fixed price, milestone-billed, no hourly surprises |

Built on the same component library you see in this repo, so you keep ownership and can extend forever.

**Get a quote:** [wei@signerlabs.com](mailto:wei@signerlabs.com) · [shipswift.app](https://www.shipswift.app/)

---

## Quick Start

### Option 1: Skills + Recipe Server (Recommended)

**Step 1** — Install ShipSwift Skills:

```bash
npx skills add signerlabs/shipswift-skills
```

**Step 2** — Connect the recipe server so your AI can fetch recipes:

```bash
# Claude Code
claude mcp add --transport http shipswift https://api.shipswift.app/mcp

# Gemini CLI
gemini mcp add --transport http shipswift https://api.shipswift.app/mcp
```

For Cursor, VS Code Copilot, Windsurf, and other tools, see the [Skills repo](https://github.com/signerlabs/shipswift-skills) for MCP setup.

**Step 3** — Ask your AI:
- "Add a shimmer loading animation"
- "Build an authentication flow with Cognito"
- "Show me all chart components"

### Option 2: Local Skills (No MCP Required)

Install skills that read source files directly from this repo — works offline, no server needed:

```bash
npx skills add signerlabs/ShipSwift
```

Your AI can then browse the component catalog and read source code locally. Try:
- "Explore ShipSwift recipes"
- "Add a shimmer animation"
- "Build a chat feature"

> **Tip**: If you also connect the MCP server (Option 1), your AI gets access to additional Pro recipes (backend guides, compliance templates, pitfall docs).

### Option 3: File Copy

1. Clone this repository
2. Copy the files you need from `ShipSwift/SWPackage/` into your Xcode project
3. Each component in `SWAnimation/`, `SWChart/`, and `SWComponent/` is self-contained — just copy the file and `SWUtil/` if needed

### Run the Showcase App

```bash
git clone https://github.com/signerlabs/ShipSwift.git
cd ShipSwift
open ShipSwift.xcodeproj
```

Select a simulator or device, then press **Cmd+R** to build and run.

---

## Components

### SWAnimation — Animation Components

**SwiftUI animations:** Shimmer · TypewriterText · ShakingIcon · GlowSweep · LightSweep · ScanningOverlay · AnimatedMeshGradient · BeforeAfterSlider · OrbitingLogos · FullScreenButton

**Metal-shader procedural backgrounds:** Dots · Starfield · FractalClouds · InkSmoke · LiquidChrome · Plasma · AnimatedLoop

**Paper Shaders ports (Metal):** Metaballs · Halftone · Water · LiquidMetal · NeuroNoise · DotOrbit · Voronoi · SimplexNoise · ColorPanels · SmokeRing · Swirl

28 animation components total — see the [Showcase App](https://apps.apple.com/us/app/shipswift-mcp-codebase/id6759209764) for live previews.

### SWChart — Chart Components

LineChart · BarChart · AreaChart · DonutChart · RingChart · RadarChart · ScatterChart · ActivityHeatmap

### SWComponent — UI Components

**Display:** FloatingLabels · ScrollingFAQ · RotatingQuote · BulletPointText · GradientDivider · Label · MarkdownText · OnboardingView · OrderView · RootTabView · VideoPlayer
**Feedback:** Alert · Loading · ThinkingIndicator
**Input:** TabButton · Stepper · AddSheet · SearchBar

### SWModule — Multi-File Frameworks

- **SWAuth** — User authentication (Amplify/Cognito, social login, email/password, phone sign-in with country code picker)
- **SWCamera** — Camera capture with viewfinder, zoom, photo picker, and face detection with Vision landmark tracking
- **SWPaywall** — Subscription paywall using StoreKit 2 — *iOS client included free. Full-stack recipe (backend + compliance + pitfalls) → [Pro](https://shipswift.app/#pricing)*
- **SWChat** — All-in-one chat view with message list, text input, and optional voice recognition (VolcEngine ASR)
- **SWSetting** — Settings page template with language switch, share, legal links, recommended apps
- **SWSubjectLifting** — Background removal using VisionKit ImageAnalysis
- **SWTikTokTracking** — TikTok Events API integration for attribution tracking — *iOS client included free. Full-stack recipe (backend + compliance + pitfalls) → [Pro](https://shipswift.app/#pricing)*

### SWUtil — Shared Utilities

DebugLog · String/Date/View extensions · LocationManager

---

## Showcase Demos

Real, runnable iOS apps built entirely with ShipSwift recipes. Each one is open-source under MIT — clone, open in Xcode, hit `Cmd+R`. No API keys, no accounts, no backend setup required.

| Demo | What it is | Recipes used |
|---|---|---|
| 🧋 [**BobaLoyalty**](https://github.com/signerlabs/bobaloyalty-ios) | Dual-side bubble tea shop loyalty app — customer ordering + owner revenue dashboard with Swift Charts | 14 |
| 🎓 [**TutorTrack**](https://github.com/signerlabs/tutortrack-ios) | Student tracker for tutors / coaches — roster, attendance, deterministic mock AI-style weekly report PDF | 17 |
| 🐾 [**Truvet**](https://github.com/signerlabs/Truvet) | Pet-owner social platform scaffold — map + community feed + chat + profile | early scaffold |

Each demo's README lists the exact recipes it pulled in via the ShipSwift MCP server. Use them as reference architectures when building your own apps.

---

## Directory Structure

```
ShipSwift/
├── SWPackage/
│   ├── SWAnimation/          # Animation components
│   ├── SWChart/              # Chart components
│   ├── SWComponent/          # UI components
│   │   ├── Display/          #   Display components
│   │   ├── Feedback/         #   Feedback components
│   │   └── Input/            #   Input components
│   ├── SWModule/             # Multi-file frameworks
│   │   ├── SWAuth/           #   Authentication
│   │   ├── SWCamera/         #   Camera + face detection
│   │   ├── SWPaywall/        #   Subscription paywall
│   │   ├── SWChat/           #   Chat + voice input
│   │   ├── SWSetting/        #   Settings page
│   │   ├── SWSubjectLifting/ #   Background removal
│   │   └── SWTikTokTracking/ #   TikTok attribution
│   └── SWUtil/               # Shared utilities
├── View/                     # Showcase app views
├── Service/                  # App services
└── Component/                # Shared app components
```

---

## Naming Convention

All types use the `SW` prefix (e.g., `SWAlertManager`, `SWStoreManager`).
View modifiers use `.sw` lowercase prefix (e.g., `.swAlert()`, `.swPageLoading()`, `.swPrimary`).

## Dependency Rules

```
SWUtil        ← no dependencies on other SWPackage directories
SWAnimation   ← may depend on SWUtil only
SWChart       ← may depend on SWUtil only
SWComponent   ← may depend on SWUtil only
SWModule      ← may depend on SWUtil and SWComponent
```

---

## Recipes

ShipSwift provides **free and pro recipes** via Skills — each recipe includes complete SwiftUI source code, implementation steps, and best practices. Your AI assistant can retrieve any recipe on demand.

| Category | Examples |
|----------|----------|
| Animation | Shimmer, Typewriter, Orbiting Logos |
| Chart | Line, Bar, Donut, Radar, Heatmap |
| Component | Alert, Onboarding, Stepper, FAQ |
| Module | Auth, Camera, Chat, Setting, Infra CDK, Subscription\*, TikTok Tracking\*, Export & Share\* |

\* Pro recipes — includes full backend, compliance templates, and pitfall guides. *Coming soon: Push Notifications, Analytics Dashboard.*

Three tools are available: `listRecipes`, `getRecipe`, `searchRecipes`.

Learn more at [shipswift.app](https://shipswift.app) · Skills repo: [signerlabs/shipswift-skills](https://github.com/signerlabs/shipswift-skills)

---

## Free vs Pro

All iOS client code is open-source under the MIT license. Pro recipes add everything you need to go from prototype to production.

| | Free (Open Source) | Pro Recipe |
|---|---|---|
| iOS client code | Full source | Enhanced version |
| Backend implementation | — | Hono routes, DB schema, webhooks |
| Integration guides | — | End-to-end setup checklists |
| Compliance templates | — | Privacy manifest, App Store labels |
| Known pitfalls | — | 10+ battle-tested tips per recipe |

More Pro recipes coming soon: **Push Notifications**, **Analytics Dashboard**.

See [pricing](https://shipswift.app/#pricing) for details.

---

## Tech Stack

- SwiftUI + Swift
- StoreKit 2
- Amplify SDK (Cognito)
- AVFoundation + Vision
- SpriteKit
- VolcEngine ASR

---

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style

- All comments and documentation in English
- All types use the `SW` prefix
- Each file in `SWAnimation/`, `SWChart/`, and `SWComponent/` must be self-contained
- Follow existing code patterns and naming conventions

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## Star History

<a href="https://www.star-history.com/?repos=signerlabs%2FShipSwift&type=timeline&legend=bottom-right">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/image?repos=signerlabs/ShipSwift&type=timeline&theme=dark&legend=bottom-right" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/image?repos=signerlabs/ShipSwift&type=timeline&legend=bottom-right" />
   <img alt="Star History Chart" src="https://api.star-history.com/image?repos=signerlabs/ShipSwift&type=timeline&legend=bottom-right" />
 </picture>
</a>

---

<div align="center">

Made with ❤️ by [SignerLabs](https://github.com/signerlabs)

</div>
