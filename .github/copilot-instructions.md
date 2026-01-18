# FS25_RedTape — AI Coding Agent Guide

Use these project-specific notes to be productive quickly when editing this mod. Keep changes minimal, follow existing patterns, and verify client/server behavior.

## Big Picture
- Entry point: `src/RedTape.lua` boots systems, injects GUI, wires message subscriptions, and handles save/load.
- Core systems: `PolicySystem`, `SchemeSystem`, `TaxSystem`, `GrantSystem` under `src/system/` drive logic; `InfoGatherer` collects data; `EventLog` records and displays events.
- Multiplayer model: Server owns authoritative state; clients receive via events and `writeInitialClientState`/`readInitialClientState` per system.
- UI: `src/gui/MenuRedTape.lua` + `MenuRedTape.xml` add a new in-game menu page with sub-sections for Policies, Schemes, Tax, Event Log, Crop Rotation, Grants. Table renderers live in `src/gui/tableRenderers/`.
- Persistence: Game-save XML `RedTape.xml` stores system state; each system implements `loadFromXMLFile`/`saveToXmlFile`.

## Client/Server & Events
- Always gate server-only code with `if (not g_currentMission:getIsServer()) then return end`.
- Notify UI via `g_messageCenter:publish(MessageType.RT_DATA_UPDATED)` when data mutates.
- Send network updates through events in `src/events/` (e.g. `PolicyActivatedEvent`, `SchemeSelectedEvent`, `NewTaxStatementEvent`). Client and server counterparts update in-memory state symmetrically.
- Each system implements `writeInitialClientState(streamId, connection)` and `readInitialClientState(streamId, connection)` to hydrate clients on join.

## Multiplayer Hydration
- General: Server appends `FSBaseMission.sendInitialClientState` to send `RTInitialClientStateEvent`; the event calls per-system `writeInitialClientState`; clients call `readInitialClientState` and publish `RT_DATA_UPDATED`.
- PolicySystem:
  - Write: `RTPolicySystem:writeInitialClientState()` — policies, farm points, warnings.
  - Read: `RTPolicySystem:readInitialClientState()` — reconstruct lists.
  - Events: `PolicyActivatedEvent`, `PolicyWarningEvent`, `PolicyFineEvent`, `PolicyPointsEvent`, `PolicyClearWarningsEvent`, `PolicyWatchToggleEvent`, `PolicyReportEvent`.
- SchemeSystem:
  - Write: `RTSchemeSystem:writeInitialClientState()` — available schemes per tier, active schemes per farm.
  - Read: `RTSchemeSystem:readInitialClientState()` — rebuild available/active lists.
  - Events: `SchemeActivatedEvent`, `SchemeSelectedEvent`, `SchemeNoLongerAvailableEvent`, `SchemeEndedEvent`, `SchemePayoutEvent`, `SchemeReportEvent`, `SchemeWatchToggleEvent`.
- TaxSystem:
  - Write: `RTTaxSystem:writeInitialClientState()` — statements, line items per farm/month, custom rates, loss rollovers.
  - Read: `RTTaxSystem:readInitialClientState()` — reconstruct statements/items/rates/rollovers.
  - Events: `NewTaxLineItemEvent`, `NewTaxStatementEvent`, `TaxRateBenefitEvent`, `TaxStatementPaidEvent`.
- GrantSystem:
  - Write: `RTGrantSystem:writeInitialClientState()` — all grants and fields.
  - Read: `RTGrantSystem:readInitialClientState()` — rebuild `grants`.
  - Events: `GrantApplicationEvent`, `GrantStatusUpdateEvent`; purchase flows call `RTGrantSystem:onPlaceablePurchased()` to pay and mark complete.
- UI Sync:
  - `MenuRedTape:onFrameOpen()` subscribes to `RT_DATA_UPDATED`; ensure publish after mutations so tables refresh.

## Systems Overview
- `PolicySystem` (`src/system/PolicySystem.lua`): Manages active policies, tier points, warnings, fines; runs `evaluate()` on policies each period; uses `FinanceStats` + `MoneyType` for fines.
- `SchemeSystem` (`src/system/SchemeSystem.lua`): Generates time-limited offers by tier, tracks farm-selected schemes, evaluates and pays out; checks spawn space for equipment.
- `TaxSystem` (`src/system/TaxSystem.lua`): Records monthly `TaxLineItem`s, produces annual `TaxStatement`s (calc in April, pay in September), supports loss rollovers and per-stat custom rates.
- `GrantSystem` (`src/system/GrantSystem.lua`): Tracks grant applications, tier-based approval odds and payout percentages, and integrates with construction purchases.
- `InfoGatherer` (`src/system/InfoGatherer.lua`): Periodic and infrequent checks feeding systems; resets monthly/biannual data.

## GUI Patterns
- `MenuRedTape.lua` renders lists via "renderer" classes (see `src/gui/tableRenderers/*`) and updates on `RT_DATA_UPDATED`.
- Use `SmoothList` with fixed cell names (`name`, `note`, `cell1` etc.) matching `MenuRedTape.xml` definitions.
- Button actions dispatch events (`PolicyWatchToggleEvent`, `SchemeWatchToggleEvent`, `SchemeSelectedEvent`). Respect availability/active state switches.

## Settings & Permissions
- Settings injection: `src/RedTapeSettings.lua` clones base settings widgets into In-Game Settings and Multiplayer Permissions.
- Server-only settings (e.g. `taxEnabled`, `policiesAndSchemesEnabled`, `grantsEnabled`, `baseTaxRate`) sync to clients via `RTSettingsEvent`; reflect enablement checks via `System:isEnabled()`.
- When adding settings: extend `RedTape.menuItems`, `RedTape.SETTINGS[...]`, l10n keys (`rt_setting_*`, `rt_toolTip_*`), and send in `RTSettingsEvent`.

## Data & Persistence
- Save key is `RedTape.SaveKey` ("RedTape"); state stored under grouped keys per system.
- On new save, `onStartMission()` seeds defaults and monthly data; on existing save, systems reconstruct from XML.

## Conventions & Integration Points
- Extend base game behavior using `Utils.appendedFunction`/`Utils.prependedFunction` on types like `FSBaseMission`, `MissionManager`, `Farm` (see `src/extensions/`).
- Money/stat types: register via `MoneyType.register` and append to `FinanceStats.statNames`; use l10n keys like `rt_ui_*`/`finance_*`.
- Time helpers: `RedTape.periodToMonth`, `RedTape.getCumulativeMonth`, `RTTaxSystem.TAX_CALCULATION_MONTH/PAYMENT_MONTH`.
- L10n lives under `languages/l10n_*.xml`; GUI texts use `$l10n_*` references in `MenuRedTape.xml`.
- `modDesc.xml` lists all `extraSourceFiles`, declares `helpLines`, and l10n prefix; add new Lua files there to ensure they load.

## Practical Tips
- When changing data models, update both save/load and stream read/write paths.
- After mutating state, publish `RT_DATA_UPDATED` so the menu reflects changes.
- For new schemes/policies: add to `RTSchemes`/`RTPolicies`, wire probabilities/tiers/offer windows, and implement evaluation. Ensure uniqueness via duplication keys.
- Systems lifecycle: implement `loadFromXMLFile` (server-only; use `hasXMLProperty` and `RedTape.SaveKey`-scoped keys), `saveToXmlFile` (server-only; guard with `isEnabled()`), `isEnabled()` (read `RedTape.settings[...]`), `writeInitialClientState`/`readInitialClientState`, and gate `periodChanged()` with `if (not self:isEnabled()) then return end`.
- Events usage: use events for data mutations, settings changes, and initial client state; avoid events for read-only UI or local-only state; follow the `Event` template with `writeStream`/`readStream` primitives, `run()` broadcasting, and call into the owning system.
- Finance integration: add stats via `FinanceStats.statNames` and `statNameToIndex`, register `MoneyType` with `rt_ui_*` and `finance_*` i18n keys; trigger money changes via `g_currentMission:addMoneyChange(...)` and `Farm:changeBalance(...)` so tax tracking works.
- UI tables: use `SmoothList` + `Slider` with fixed cell names; back with a renderer in `src/gui/tableRenderers/` implementing `setData`, `getNumberOfItemsInSection`, `populateCellForItemInSection`, and selection callbacks; toggle containers by `setVisible()` and `reloadData()` after `RT_DATA_UPDATED`.
- Code style: allow `continue`; avoid `goto`; prefer `pairs` plus local counters over `ipairs` for sparse tables; use early returns, nil checks, and server gating; cache frequent lookups.
