# GoblinFlip 0.7.0

Auction-house vendor flips and disenchant estimates for the WoW Forever 1.60.1 client (interface 16001). This release repairs startup and UI integration and adds first-run setup, feature health, live purchase review and transaction recovery.

## Install and start

Extract the release ZIP so `Interface/AddOns/GoblinFlip/GoblinFlip.toc` exists. Enable the addon and log in. Setup opens on first login; it can be skipped and resumed with `/gf setup`.

1. Check providers and choose Auctionator or Native in setup.
2. Set the budget and per-purchase limit. Setup accepts copper or explicit units such as `1g 20s`. Zero budget/limit means unlimited.
3. Visit an auction house and verify the detected market. Choose the correct market override in Settings if needed.
4. For Auctionator, manually click its **Get All** action. For Native, click **Scan** in GoblinFlip. Native availability depends on replicate APIs/events in the client.
5. Select a result, review its **live** quote, click **Review purchase**, then **Confirm purchase**. Each submission requires its own confirmation.

`/gf` opens the shared workspace in a separate window. The auction-house tab uses the same workspace. The minimap icon opens the window; right-click provides navigation. Window mode and scan provider are independent.

## Providers and health

Auctionator is optional when native replicate scanning is available. Its integration requires the supported FullScan event-bus contract; GoblinFlip does not guess a programmatic scan trigger. DisenchantBuddy is optional and requires its supported `API.v1.GetAverageDisenchantValueByItemID` interface.

**Health / setup** shows per-feature status, recovery steps and Recheck. It distinguishes absent, disabled, unloaded and incompatible external addons where the client provides addon-status APIs. Vendor flips do not require DisenchantBuddy. Libraries and their dependencies are bundled; see [THIRD_PARTY.md](THIRD_PARTY.md).

## Calculations and safeguards

Vendor proceeds = quantity × vendor unit price. Profit = proceeds − whole-lot buyout. ROI = 100 × profit / buyout. For example, 20 items at 375c vendor price with a 5000c buyout yield 2500c profit and 50% ROI.

The live quote is evaluated again against minimum profit/ROI, current funds, market, expiry, purchase limit and session budget. Transaction costs use whole copper; expected values may be fractional and are rounded for display. Losses retain their minus sign.

Disenchant values are estimates. Provider net values are treated as net; gross values have fees deducted once. Internal tables use fixed illustrative material prices, are marked stale, and **cannot be used to purchase**. Their tables and server-specific assumptions still need independent validation. Commodity buying is unavailable in this release.

Current defaults: minimum profit **1s**, minimum ROI **0%**, per-purchase maximum **2g**, session budget **20g**, live quote lifetime **10 seconds**. Money fields in the regular Settings/filter panels are labelled in gold; setup fields accept explicit units.

## Ledger and recovery

One submitted purchase remains pending until its outcome is known. A general money decrease is insufficient evidence of a particular purchase. If no reliable confirmation arrives, GoblinFlip marks the outcome uncertain after the timeout. Verify the actual result in-game and use **Verify bought** or **Verify failed** in Ledger. Reload restores unresolved records and blocks new purchases until they are resolved. Confirmed spend is charged once; budget/data resets are blocked while outcomes are pending.

Ledger supports manual entries, partial receipt quantities, actual proceeds and full reversal of the most recent disposal after a verified buyback/refund. Mail/merchant observations are informational; they do not automatically credit receipts or profit. History snapshots are read-only. Newer or invalid saved-data schemas leave the original data untouched and disable trading/saving.

## Commands

| Command | Action |
| --- | --- |
| `/gf` | Open opportunities |
| `/gf setup` | Resume setup |
| `/gf health` | Refresh feature health |
| `/gf scan` | Request selected scan provider |
| `/gf settings` | Open settings |
| `/gf settings scanProvider native` | Select native provider |
| `/gf settings minProfit 100` | Set minimum profit to 100 copper |
| `/gf standalone` | Toggle separate window |
| `/gf diagnostics` | Print diagnostics |
| `/gf budget` | Reset budget when no outcomes are pending |
| `/gf reset` | Confirm removal of saved addon data |

## Development checks

From the repository root:

```sh
lua Tests/run.lua
GF_TEST_LOCALE=deDE lua Tests/run.lua
python3 scripts/package.py
```

The dependency-free mock suite exercises exact TOC loading, setup, workspace construction, scan metadata, native tuple/table payloads, live review/confirmation, uncertainty/recovery, calculations, ledger and saved-data protection. CI runs it with Lua 5.1 and 5.4 and checks parsing/release packaging. ZIP output is `dist/GoblinFlip-0.7.0.zip`.

Mock tests cannot establish actual Forever API compatibility or visual layout. Before distributing, run the [in-game checklist](docs/IMPLEMENTATION.md) on the target client with no optional addons and with the intended provider versions.
