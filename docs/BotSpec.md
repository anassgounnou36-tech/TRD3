# XAUDailyFlowEA Bot Specification

XAUDailyFlowEA is a pure MQL5 intraday bot for XM GOLD aliases (GOLD/XAUUSD/XAUUSDm/XAUUSD.*). It is a session-based daily-opportunity engine that combines:

- Opening Range Breakout continuation (ORB)
- Failed OR / VWAP mean reversion

## Core principles

- M1 data for OR/VWAP calculations
- M5 for setup qualification and execution cycle
- M15 context for regime bias (real EMA slope/alignment context)
- London and New York windows only
- No overnight hold and no swing bias
- Market execution only
- Strict daily loss and trade count controls

## v1.1 quality upgrades

- Session-state persistence fixed so same-session flags (`touched_above`, `touched_below`, `or_complete`) are preserved across ticks and reset only on session rollover.
- Regime engine now receives real M15 context from indicator handles (EMA alignment + slope), rather than placeholder values.
- Scoring upgraded to evidence-based components (OR normalization, trigger structure, execution quality via spread/RR, VWAP quality and penalties).
- Execution diagnostics now log pre-send and post-send details (retcodes, order/deal IDs) and SL modify diagnostics.
- Bar audit script now outputs strategy-aware state (OR/VWAP/regime/signals/score/blocker) to speed validation.

## v1.2 quality upgrades

- Bar audit upgraded to historical strategy-audit mode (date-range or bar-count) with per-checkpoint OR/VWAP/regime/signal/score/blocker output.
- No-trade filtering upgraded with adaptive checks (ATR-relative spread limits, ATR-relative VWAP distance, and compression dead-session detection).
- Risk sizing supports input-controlled capital source selection (`EQUITY` default, optional `BALANCE`).
- Execution diagnostics now include family, regime, score, target distance, and SL delta on modify.
- Regime logs now include explicit reason strings to reconstruct setup decisions from logs.

## v1.3 quality hardening

- BarAudit now reuses the same shared strategy-decision path as live EA for regime, signal family evaluation (ORB/MR), setup selection, scoring, and blocker evaluation.
- Execution engine adds preflight validation categories (`invalid symbol`, `invalid stop distance`, `invalid volume`, `spread violation`, `market not tradable`, `order send failed`, `modify failed`) with explicit diagnostics.
- Execution flow now logs `OrderCheck` details and no longer silently swallows check failures.
- Filtering is more context-aware: spread and VWAP distance are evaluated relative to ATR and session behavior; OR-width and dead-session checks include adaptive behavior-aware bounds.
- Position lifecycle is phase-driven (`INIT`, `OPEN`, `TP1_REACHED`, `BE_ACTIVE`, `RUNNER_TRAIL`, `TIME_EXIT`, `COMPLETE`) with calmer one-time BE and bar-gated meaningful trailing updates.
- Panel transparency improved with OR-built status, setup candidate, score, blocker reason, and position-state visibility.
- Init logs now explicitly print resolved symbol, server time, and configured London/New York windows for broker-time validation.

## v1.4 final hardening pass

- Opening range construction is now exact and deterministic via explicit M1 shift iteration (session start inclusive, OR end exclusive), with OR debug traces.
- EA and BarAudit both use one shared decision entrypoint (`XDF_EvaluateDecision`) to remove audit/live decision drift.
- Session persistence is explicit via runtime session-state helpers (new-day/new-session reset, touch updates, same-session checks).
- M15 context is first-class (fast EMA, slow EMA, slope, ATR, alignment, slope strength, price-vs-fast) and consumed by regime/scoring.
- Filters prioritize contextual relationships (spread/ATR/session behavior, VWAP/ATR/OR width, OR-width extremes, compression/chop context) with fixed limits as safety caps.
- Blockers use stable categories and consistent enum+message diagnostics across logs/panel.
- Execution preflight captures normalized request snapshots (trade mode/fill mode/volume constraints/deviation) and classifies failures before send.
- Position management is state-driven (`MGMT_NONE`, `MGMT_OPEN`, `MGMT_TP1_ARMED`, `MGMT_BE_DONE`, `MGMT_TRAIL_ACTIVE`, `MGMT_TIME_EXIT`, `MGMT_COMPLETE`) with calmer transition logging.
- Dashboard panel expanded to include server time, OR width, eligible/selected families, M15 context summary, management state, and daily lock state.

## v1.4.1 compile + elite hardening

- Fixed compile defects from MetaEditor: removed static-array `ArraySetAsSeries` misuse in active decision paths, replaced retcode enum string-casting with manual trade-retcode mapping, and restored explicit `regime` panel plumbing through signature + callsites.
- Added shared `ContextBuilder.mqh` so EA and BarAudit build decision context through one path (session + OR + VWAP + spread + M15 context + diagnostics), reducing remaining audit/live drift vectors.
- Added reusable OR validation diagnostics (`session_start` inclusive, `or_end` exclusive) reporting shifts, included bars, and resulting OR values.
- Improved historical-context handling by adding time-anchored indicator helpers (`ATRAt`, `BuildM15ContextAt`) used by shared context building.
- Strengthened init diagnostics to log London/NewYork start, OR end, and trade end timestamps in broker server time.

## Time assumptions

- Session inputs are interpreted in **broker server time**.
- Defaults are calibrated for XM-style London/NY server-time windows and should be adjusted if broker server offset differs.
- Always validate session alignment on your broker/XM server (including DST changes) before trusting default windows.
