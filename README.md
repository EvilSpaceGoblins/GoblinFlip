# GoblinFlip

### Buy low. Vendor smart. Know your numbers.

Find auction-house vendor flips, compare disenchant estimates, and track what you actually earn on **WoW Forever**.

![Version](https://img.shields.io/badge/version-0.7.0-e6b450)
![Target client](https://img.shields.io/badge/target-WoW_Forever_1.60.1-1488cc)
![Interface](https://img.shields.io/badge/interface-16001-555555)
![Lua](https://img.shields.io/badge/Lua-addon-2c2d72)
![Locales](https://img.shields.io/badge/locales-English_%2F_German-679b45)

[Quick start](#quick-start) · [Features](#what-it-does) · [Providers](#providers--dependencies) · [Commands](#commands) · [Development](#development)

## TL;DR

**Scan the auction house → find a margin → review the live price → confirm a purchase → track the outcome.**

GoblinFlip compares whole-auction buyouts with vendor proceeds or disenchant estimates. It gives you filters, spending limits, a transaction ledger, and a resumable setup guide. Every purchase needs your confirmation.

> **Release status:** 0.7.0 includes startup, UI, calculation, and recovery repairs. Automated mock tests pass; compatibility and layout still need verification in the actual Forever client. Commodity purchasing is currently unavailable.

## What it does

| Feature | What you get |
| --- | --- |
| **Vendor flips** | Find auctions whose vendor value exceeds their whole-lot buyout. |
| **Disenchant estimates** | Compare expected material value, with provider and stale-data indicators. |
| **Profit filters** | Narrow results by profit, ROI, quality, and search text. |
| **Live purchase review** | Recheck a quote against your funds, limits, market, and quote expiry. |
| **Spending controls** | Set a per-purchase maximum and a session budget. |
| **Transaction ledger** | Record purchases, partial receipts, actual proceeds, and manual corrections. |
| **Scan history** | Browse saved snapshots without turning old results into live purchase offers. |
| **First-run setup** | Choose a provider, check dependencies, and configure safeguards. |
| **Flexible workspace** | Use an auction-house tab or a separate window, with minimap access. |

## Quick start

### 1. Install

Extract the release ZIP into your WoW installation so this file exists:

```text
Interface/AddOns/GoblinFlip/GoblinFlip.toc
```

Enable **GoblinFlip** in the addon list and log in. Required libraries are bundled.

### 2. Run setup

Setup opens on first login. You can skip it and resume at any time:

```text
/gf setup
```

Choose **Auctionator** or **Native** as your scan provider, review feature health, and set your spending limits. Setup accepts amounts such as `1g 20s`; regular Settings money fields are labelled in gold. **Zero budget or purchase limit means unlimited.**

### 3. Scan and review

1. Visit an auction house and check the detected market. Use the market override in Settings if necessary.
2. With **Auctionator**, manually click its **Get All** action. With **Native**, click **Scan** in GoblinFlip.
3. Select an opportunity and review its fresh quote.
4. Click **Review purchase**, then **Confirm purchase**.
5. Check the result in-game and resolve any uncertain transaction in **Ledger**.

Use `/gf` to open the workspace. The minimap icon opens it too; right-click the icon for navigation. Window preference and scan provider are separate settings.

## Providers & dependencies

| Component | Required? | Purpose |
| --- | --- | --- |
| **Bundled libraries** | Included | UI integration, callbacks, and minimap access. |
| **Auctionator** | Optional | Full-scan data through its supported event-bus contract. Start **Get All** yourself. |
| **Native auction API** | Alternative scan provider | Requires working replicate APIs and events in your client. |
| **DisenchantBuddy** | Optional | Disenchant values through `API.v1.GetAverageDisenchantValueByItemID`. |

Open **Health / setup** for feature status, recovery steps, and **Recheck**. Where client APIs allow, it distinguishes missing, disabled, unloaded, and incompatible addons. Vendor flips do not require DisenchantBuddy.

Library provenance and licenses are listed in [THIRD_PARTY.md](THIRD_PARTY.md).

## How the numbers work

```text
Vendor proceeds = quantity × vendor unit price
Profit          = proceeds − whole-lot buyout
ROI             = profit ÷ buyout × 100
```

**Example:** 20 items worth 375 copper each have a vendor value of 7,500 copper. At a 5,000 copper buyout, that is **25 silver profit** and **50% ROI**.

Disenchant results are estimates. Provider net values remain net; gross values have fees deducted once. Internal material prices are illustrative, marked stale, and cannot authorize purchases. Server-specific material values and probabilities still need independent validation.

### Default safeguards

| Setting | Default |
| --- | --- |
| Minimum profit | **1 silver** |
| Minimum ROI | **0%** |
| Maximum per purchase | **2 gold** |
| Session budget | **20 gold** |
| Live quote lifetime | **10 seconds** |

Before submission, GoblinFlip checks the current quote, funds, market, expiry, filters, and spending limits again. Transaction costs use whole copper; fractional expected values are rounded for display.

## Ledger & recovery

A money decrease alone cannot prove which auction was purchased. If no reliable confirmation arrives, the transaction becomes **uncertain** after the timeout.

Verify the outcome in-game, then choose **Verify bought** or **Verify failed** in Ledger. Unresolved transactions survive reloads and block further purchases and budget/data resets. Confirmed spend is charged once.

The ledger also supports manual entries, partial receipts, actual proceeds, and reversal of the most recent disposal after a verified buyback or refund. Mail and merchant observations do not automatically credit items or profit. Newer or invalid saved-data schemas preserve the original data and disable trading and saving.

## Current limits

- **Commodity purchases are disabled.** Quantity-based commodity orders need their own price-confirmation flow, which this release does not implement.
- **Internal disenchant tables are illustrative.** They are useful for inspection, but cannot be used to buy.
- **Purchase outcomes can require manual verification.** General money events are insufficient evidence.
- **Actual client testing is still required.** Mock tests cannot prove Forever API compatibility or visual layout.

## Commands

| Command | Action |
| --- | --- |
| `/gf` | Open opportunities |
| `/gf setup` | Resume setup |
| `/gf health` | Refresh feature health |
| `/gf scan` | Request the selected scan provider |
| `/gf settings` | Open settings |
| `/gf settings scanProvider native` | Select the native provider |
| `/gf settings minProfit 100` | Set minimum profit to 100 copper |
| `/gf standalone` | Toggle the separate window |
| `/gf diagnostics` | Print diagnostics |
| `/gf budget` | Reset the budget when no outcomes are pending |
| `/gf reset` | Confirm removal of saved addon data |

## Development

Run from the repository root:

```sh
lua Tests/run.lua
GF_TEST_LOCALE=deDE lua Tests/run.lua
python3 scripts/package.py
```

The dependency-free mock suite covers TOC loading, setup, workspace construction, scan payloads, purchase review and confirmation, recovery, calculations, ledger behavior, and saved-data protection. CI is configured for Lua 5.1 and 5.4, syntax checks, and packaging.

The package script creates `dist/GoblinFlip-0.7.0.zip`. Before distribution, follow the [implementation notes and in-game checklist](docs/IMPLEMENTATION.md) with and without the intended optional addons.
