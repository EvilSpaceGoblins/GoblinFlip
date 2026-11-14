# GoblinFlip audit and upgrade plan

Implementation follow-up: the 0.7.0 changes are recorded in [IMPLEMENTATION.md](IMPLEMENTATION.md). The findings below describe the pre-fix state and are retained as the audit baseline.

Audited 2026-11-14 against the current working tree. Existing edits to GoblinFlip.toc and README.md were preserved. This document plans implementation; addon behavior has not been changed.

## Assessment

The domain/adapters/UI separation is useful, but a fresh installation cannot reliably start. Several advertised workflows have disconnected wiring or unfinished implementations. Repair the working scan → results → quote → confirm → ledger path before adding onboarding.

Evidence: manifest/module inspection, temporary graphify relationship graph, syntax checks and isolated Lua probes. No live WoW client was exercised. Local Lua is 5.5.1; target-client API contracts, templates, server rules and external addon versions still need verification.

## Findings

| Priority | Finding and evidence | Fix |
| --- | --- | --- |
| P0 | **No startup bootstrap.** Events.lua:189,284 define Initialize/RegisterEvents, but no file-scope code invokes either. Mock TOC execution creates zero frames; initialization and slash registration never run. | Register initial events during load; initialize once on ADDON_LOADED; defer UI readiness to login; make failures retry-safe. |
| P0 | **Missing transitive library.** LibDBIcon.lua:10 and LibDataBroker.lua:9 require CallbackHandler-1.0, which is not bundled or declared. Both throw in clean-load probes. | Bundle compatible maintained libraries and dependencies in deterministic order. |
| P0 | **AH library identifier mismatch.** Embedded LibAHTab registers `LibAHTab-1-0`; MainTab.lua:22 and minimap navigation request `LibAHTab-1.0`. | Centralize library lookup and use the registered identifier. |
| P0 | **Invalid widget calls.** Dashboard.lua:46, BuyPane.lua:64, Filters.lua:42 and History.lua:45 use dot calls and chain SetPoint results; Options.lua:237 also chains SetPoint. | Use separate colon calls on the created widget; check title/backdrop/menu/template compatibility in the actual client. |
| P0 | **AH workspace is incomplete.** MainTab.Create never hooks OnShow or calls BuildUI. Its dashboard builds no filters/results/buy pane. Failed attachment leaves frame set, preventing a real retry. | Build one complete workspace and connect lifecycle hooks; publish attachment state only after success. |
| P0 | **Purchase UI skips required states.** Standalone selection only calls Select/SetOpportunity; Buy calls SubmitPurchase directly. No UI caller invokes BeginConfirm. Probe returns `confirmation_required` even with a quote. | Wire selection → live quote → review → explicit confirmation → submit; display the actual quote, not scanned prices. |
| P1 | **No UI controller.** Events.lua:58 calls GF.UI.Notify, which is undefined; GF.UI.Initialize is also absent. | Implement subscriptions, visible-view refresh and actionable error reporting. |
| P1 | **Filters/settings are disconnected.** Filters calls nonexistent App:GetStrategy. Settings.Set rejects search/qualityFilter; callbacks are unwired. UI directly calls Settings.Set, bypassing App:SetSetting side effects. | Define one view/controller contract; validate supported settings and route edits through application commands. |
| P1 | **Minimap actions do not reach handlers.** Bundled DBIcon fires bus callbacks but never invokes object.OnClick/OnTooltipShow supplied by MinimapIcon. Minimap data is stored both under db.settings and at db root. | Use compatible maintained implementations and one saved-data structure. |
| P1 | **Dependency reports disagree.** CheckDependencies, Compat.Probe, readiness and provider selection implement different rules. Reports may be cached before AH exists; later checks do not reprobe or register late Auctionator. | One feature-level capability model, refreshed on relevant addon/AH events and provider changes. |
| P1 | **Commodity detection passes the wrong argument.** LiveMarket.IsCommodity is a dot function called with colon at lines 103/235. Same-key probe produces true with dot and false with colon. | Normalize calling conventions and add adapter contract coverage. |
| P1 | **Commodity purchase protocol is unfinished.** Events.lua:1037 starts purchase; no commodity price-update/confirmation path completes it. | Keep unavailable until full quote/price-change/confirm/cancel/completion support is validated. |
| P1 | **Internal DE fee omitted.** DisenchantData.lua:499 labels pre-fee value expectedNetPerItem; strategy deliberately skips fees for net inputs. Probe confirms no claimed 5% deduction. | Supply gross and deduct once, or supply genuinely net proceeds. |
| P1 | **Internal DE source/skill claims conflict.** Events.lua:575 always uses fixed defaultPrices. Estimates are stamped current/non-stale and skillVerified=false, so default skill checks reject them; status UI claims verified=true. | Use observed market prices with age/coverage, real skill evidence and one status contract. Fixed fallback prices must be illustrative and non-executable. |
| P1 | **DE metadata is lost.** Normalizer defaults itemLevel to zero; ItemInfo.ResolveOne does not cache returned level; ProfitEngine drops level from opportunities used for live validation. | Carry resolved level/class/variant through scan, cache, opportunities, history and live evaluation; validate actual disenchant eligibility. |
| P1 | **Pending spend is not restored.** Initialize creates a new PurchaseManager without rebuilding unresolved reservations from saved submitted/uncertain ledger records. | Recover unresolved transactions and idempotent budget charges across reload before permitting more purchases. |
| P1 | **Money decrease is treated as confirmation.** Events.lua:1158 accepts any sufficient decrease; unrelated spending can satisfy it and concurrent income can conceal a purchase. | Require auction-specific evidence; preserve ambiguity and never automatically retry uncertain purchases. |
| P1 | **Future-schema protection mutates data.** Settings.Initialize normalizes the original saved table before checking schema and adds defaults despite claiming no modification. Reproduced by probe. | Keep newer schemas untouched; use a separate compatibility/read-only model and validate malformed saved records. |
| P2 | **Display contracts mismatch.** UI reads avgRoi but engine returns roi; UI ledger totals differ from domain field names. Widgets.FormatMoney hides losses as 0c and fails on fractional copper locally. Events tooltip divides ROI by ten. | One documented metrics contract and signed money/estimate rounding policy. |
| P2 | **History contract mismatch.** App:GetHistory returns one market's history list; UI expects a market map containing snapshots. Selection callback is unwired; refresh recreates dropdowns. | Explicit market/snapshot APIs, reused controls and read-only navigation. |
| P2 | **Ledger completion unfinished.** AddProceeds prints Not yet implemented; manual entry prints saved without persistence. Mailbox listener has no subscriber; merchant sale-to-ledger linkage is TODO. | Validated forms and conservative, deduplicated reconciliation supporting partial quantities and buybacks. |
| P2 | **Scrolling/sorting incomplete.** Results renders only first-viewport rows despite a full-height content area; refresh sorts application rows in place. | Real virtualization or bounded full population, stable order and selection by listing identity. |
| P2 | **Navigation/localization drift.** Extended deDE loads before Localization overwrites GF.L; settings only shows existing frames; README's settings setter is unimplemented. Singleton panels are reparented between hosts. | Central lazy navigation, one locale merge and an explicit shared-workspace ownership model. |
| P2 | **Release claims are unreproducible.** No tracked tests/CI despite 68/68 badge. TOC says 0.6.0; Core says 1.2.0. maxBuyout=20000c is 2g, while README says 20g. | Restore tests and release checks; align metadata, defaults and documented capabilities. |

## Calculation assessment

Vendor baseline is correct: 20 × 375c − 5000c = 2500c profit, ROI 50%. Stack cost and unit price are distinct; invalid/zero costs are rejected. Retain live re-evaluation, expiry, explicit confirmation, single pending submission, budgets and read-only snapshots.

Add derived-product/sum bounds, finite-number validation for provider costs/fees, explicit expected-value rounding and partial-disposal allocation/reversal checks. Aggregate grouped confidence/staleness conservatively. Decide whether minimum profit/ROI are discovery-only or purchase constraints: live re-evaluation currently only requires positive profit and purchase limits.

Internal tables infer expansion from item level alone. Material IDs, probabilities, eligibility, market fees and Forever-specific rules require a data-validation pass before actionable DE recommendations.

## Implementation sessions

### 1. Restore startup and usable workspace — P0

Bootstrap, library packaging/identifiers, widget calls, retry-safe AH attachment, UI controller, complete results/filter/buy layout and reachable settings/minimap.

Acceptance: clean saved variables and no optional addons produce no login errors; /gf reaches the workspace; AH open/close/reopen does not duplicate frames; a provider scan updates results without reopening the window.

### 2. Correct trading, estimates and persistence — P1

Wire quote/review/confirm; repair adapter conventions and capability refresh; keep commodities unavailable; fix DE fees, price/skill evidence and metadata; restore unresolved spend; strengthen confirmation and saved-data protection.

Acceptance: stale quote, wrong market, closed AH, insufficient funds and budget limits block buying. Double-click submits once. Reload cannot bypass pending spend. Uncertain results stay unresolved. Fixed DE defaults never support an executable recommendation.

### 3. Add onboarding and unified dependency detection

Persist onboardingVersion and completed/skipped/resumable progress. Display after login when safe; add `/gf setup` to resume or rerun. No setup step spends gold or automatically scans.

1. **Welcome/client check:** detected client/build/version and supported features; diagnostics/read-only fallback where possible.
2. **Dependency health:** separate scan, item-info, AH UI, live query/buy and DE capabilities. Distinguish missing, disabled, installed-but-unloaded, incompatible and ready; explain affected feature and recovery action; include Recheck.
3. **Provider choice:** recommend a detected working provider. Offer native only with required APIs/events; explain manual Auctionator Get All. Keep window mode separate from provider selection.
4. **Safeguards:** budget, per-purchase limit, minimum profit/ROI, explicit currency units and zero/unlimited semantics.
5. **DE setup:** vendor-only remains usable; show randomness, skill evidence and price age/coverage. Enable actionable DE only with validated inputs.
6. **First scan guide:** visit AH, verify/override market, manually scan; progress, cooldown/error recovery and distinct empty-result reasons.
7. **Workflow walkthrough:** quote → confirm → submitted/uncertain → receipt → disposal → realized profit, without requiring a purchase.

Keep a compact health panel after setup. Recheck must refresh capabilities and retry adapter registration. Missing optional features must not block usable ones or produce repeated login spam.

Acceptance: first scan is discoverable without slash-command knowledge; skip/resume/reload work; missing DE does not block vendor flips; absent providers lead to clear recovery steps.

### 4. Finish tracking, history and release verification — P2

Complete receipt/proceeds/manual-entry workflows, mail/merchant reconciliation and reversals; repair history, scrolling, selection and metrics; consolidate tooltips/locales; verify sizes/UI scales; align README and release metadata; add CI and clean-install packaging checks.

Acceptance: realized profit follows recorded proceeds and allocated cost; partial operations/reversals never double count; history remains read-only; losses display correctly; packaged addon works without another addon's library copies.

## Verification matrix

- Installation: fresh/existing/malformed/future DB; no dependencies, each alone, both, late/incompatible providers; enUS/deDE; reload/relog.
- UI: settings before AH load; AH reopen; standalone transitions; repeated navigation; small viewport/UI scale; empty/large lists and sorting/selection.
- Scan: provider fixtures and actual native return shape; partial/empty payloads; missing item cache; lost event, cooldown, cancellation, repeated requests and market change. Native waiting currently lacks timeout and accepts unsolicited replicate events; add request/generation ownership.
- Calculations: stack/unit cost, fee once, finite/large numbers, signed/fractional display, unknown/stale DE inputs, skill mismatch, weighted ROI and partial disposal/reversal.
- Purchases: changed price/quantity, stale generation, expiry, double click, AH closure, market/funds/budget changes, unrelated money movement, timeout and reload recovery.
- Release: complete TOC paths and bundled libraries, reproducible test results, actual Forever client/provider contract fixtures and in-game smoke test.

## Checks completed during this audit

- All 41 Lua files pass local luac syntax checks; all TOC Lua paths exist and all Lua files are listed.
- Mock TOC execution reproduces missing CallbackHandler errors, zero startup frames and absent slash registration.
- Probes reproduce rejected search, missing controller methods, omitted internal DE fee, future-schema mutation, commodity calling-convention error, negative-money masking, fractional formatting failure and direct-submit confirmation rejection.
- Temporary graph artifacts remain under /tmp/goblinflip-audit-graph, outside the addon.
- No live API signatures, server rules, external addon releases or README test claims were independently verified.
