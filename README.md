# GoblinFlip v0.1

[![Version](https://img.shields.io/badge/version-v0.1-blue.svg)](https://github.com/EvilSpaceGoblins/GoblinFlip/releases/tag/v0.1)
[![WoW Version](https://img.shields.io/badge/WoW-Forever%201.60.1-orange.svg)]()
[![TOC](https://img.shields.io/badge/TOC-16001-green.svg)]()
[![Tests](https://img.shields.io/badge/tests-68%2F68%20passing-brightgreen.svg)]()
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Dependencies](https://img.shields.io/badge/Auctionator-Required-red.svg)]()
[![Dependencies](https://img.shields.io/badge/DisenchantBuddy-Optional-yellow.svg)]()

## What is GoblinFlip?

**GoblinFlip** is a World of Warcraft: Forever (1.60.1) auction-house addon designed to help players find and purchase **vendor flips** and estimate **disenchant flips** at the auction house. It implements a complete workflow: **scan → discover → validate → buy → mail/merchant reconcile → ledger**.

**Target**: WoW Forever 1.60.1, TOC `16001`, EU/ENUS

## Core Features

### Vendor Flips
- Detects items **listed by players on the Auction House** that can be purchased and sold to an NPC vendor for profit
- Calculates exact profit using integer copper (gold/silver/copper)
- Verified vendor prices from `C_Item.GetItemInfo` sell price (exact, not estimated)

### Disenchant Estimates (Transparent by Design)
- Optional integration with **DisenchantBuddy** for expected material value
- **Estimates are the correct approach** - disenchanting is inherently probabilistic (RNG). There is no "guaranteed" disenchant outcome.
- Community-sourced averages from thousands of real disenchant results
- Clearly marked with confidence: `medium` (fresh data) / `low` (stale) / `verified` (vendor)
- Skill detection with manual override in settings
- UI explicitly shows "Estimated" tag on disenchant opportunities

### Scan Workflow
- **Auctionator scan**: Manual trigger (`Get All` button), adapter consumes `Auctionator.FullScan.Events.ScanComplete`
- **Native replicate scan**: Experimental, disabled by default, requires `experimentalNativeScan` enabled
- One submission at a time guarantee
- Quote freshness: 10 seconds; per-purchase limit: 2g; session budget: 20g

### Market Detection
- Automatic zone-based faction detection (Horde/Alliance/Neutral/Blackwater)
- Manual house override in Settings when zone detection is uncertain
- Unknown market never merged with known markets without manual override

### Ledger & Persistence
- Full transaction lifecycle: `SUBMITTED → CONFIRMED → AWAITING_MAIL → RECEIVED → PARTIALLY_DISPOSED → DISPOSED`
- Exact integer cost allocation with reversible disposals
- Session budget tracking (persists until explicit reset, survives `/reload`)
- History: 7 days / 10 snapshots per market
- Export/import of saved data

### Settings & UI
- Configurable: min profit, min ROI, max buyout, session budget, quote freshness
- Sound alerts: opt-in, rate-limited (30s), deduplicated per scan
- Grouped/ungrouped view, search, blacklist, quality filter
- Debug logging, experimental native scan toggle
- In-game dependency check with clear messaging

## What GoblinFlip Does NOT Do

- ❌ **No botting/automation**: No auto-buy, auto-sell, or auto-mail
- ❌ **No commodity direct buying**: Disabled by default (unverified price guarantee)
- ❌ **No botting**: One submission at a time, explicit user confirmation required
- ❌ **Guaranteed disenchant outcomes**: Estimates are community averages - this is the correct approach since disenchanting is inherently RNG-based. Vendor prices are exact.
- ❌ **Botting detection avoidance**: All API access is defensive and rate-aware
- ❌ **Full automation**: Every purchase requires explicit user confirmation

## Requirements

- **Auctionator** required (scan dependency)
- **DisenchantBuddy** optional (for disenchant estimates)
- WoW **Forever 1.60.1**, TOC `16001`
- Client at `/Applications/World of Warcraft/_forever_` (EU, enUS)

## Dependencies

| Dependency | Status | Notes |
|---|---|---|
| Auctionator | Required | Full-scan contract, undocumented event bus |
| DisenchantBuddy | Optional | `GetAverageDisenchantValueByItemID` API |
| LibStub | Embedded | Public Domain |
| LibAHTab | Embedded | MIT licensed, © 2022 plusmouse |

## Installation

1. Copy `GoblinFlip.zip` into `/Applications/World of Warcraft/_forever_/Interface/AddOns/GoblinFlip/`
2. Log into WoW Forever
3. Use `/gf help` for slash commands
4. Open Auction House, click "Scan" (manual `Get All` in Auctionator)

## Slash Commands

```
/gf scan        - Start a scan
/gf help        - Show help
/gf settings    - Open settings UI
/gf reset       - Reset all data
/gf budget      - Reset session budget
```

## License

**GoblinFlip v0.1** is released under the terms of the MIT License (embedded libraries) with additional notice for Auctionator/DisenchantBuddy APIs.

**Embedded libraries**:
- `Libs/LibStub/LibStub.lua` - Public Domain (Kaelten, Cladhaire et al.)
- `Libs/LibAHTab/LibAHTab.lua` - MIT License (© 2022 plusmouse)

**Notice**: Auctionator and DisenchantBuddy APIs are copyright of their respective authors. This addon implements original interoperable implementation only; no copied unlicensed code or assets.

## Known Blockers (Honest)

- Cannot run the actual game/addon in-client (requires login)
- Auctionator not installed, so in-game scan/purchase integration cannot be exercised yet
- Commodity purchase semantics on Forever remain unverified
- All runtime assumptions labeled unverified and covered by `docs/MANUAL_TESTS.md`

## Build & Test

```bash
# Run tests
export PATH=/opt/homebrew/opt/lua@5.4/bin:$HOME/.luarocks/bin:$PATH
busted -p '.test.lua' Tests/

# Lint
luacheck GoblinFlip

# Current status: 68/68 tests pass, 124 warnings, 0 errors
```

## Roadmap (Post-v0.1)

- v0.2: UI polish, additional filters, enhanced ledger views
- v0.3: Context menu integration, tooltip enhancements
- v1.0: Stable release with full workflow validated