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

## v1.5 elite signal-generation upgrade

- Signal evaluation is now timestamp-aware: ORB/MR modules expose shift-based `EvaluateAt(...)` and use closed M5 bars aligned to the evaluated timestamp.
- Shared context carries evaluated M5 shift/time plus aligned closed-bar window inputs, reducing historical audit drift.
- ORB now supports multiple continuation subtypes (direct breakout, retest-hold, two-bar continuation, break-close-hold) and chooses best valid candidate.
- MR now supports multiple reclaim/failure subtypes (immediate sweep-reclaim, failed-break confirm, delayed reclaim window, reclaim+midpoint/VWAP confirm) and chooses best valid candidate.
- Added explicit `BLOCKER_NO_SETUP` to distinguish true no-setup outcomes from regime blocks.
- Mixed regime remains tradable by scoring both families and selecting higher-quality valid candidate.
- Family-specific filtering behavior introduced: ORB tolerates larger VWAP extension (with scoring penalty), MR remains stricter.
- BarAudit output now surfaces `orb_valid`, `mr_valid`, `orb_subtype`, `mr_subtype`, `orb_score`, `mr_score`, and reject reason for faster root-cause diagnosis.

## v1.5.1 final strategy-selectivity fix

- ORB continuation generation broadened to explicit subtype set: `ORB_DIRECT_BREAK`, `ORB_BREAK_RETEST_HOLD`, `ORB_TWO_BAR_CONFIRM`, `ORB_BREAK_PAUSE_CONTINUE`.
- MR reclaim/failure generation broadened to explicit subtype set: `MR_IMMEDIATE_SWEEP_RECLAIM`, `MR_FAILED_BREAK_NEXT_BAR_CONFIRM`, `MR_DELAYED_RECLAIM_WINDOW`, `MR_RECLAIM_THEN_MIDPOINT_CONFIRM`, `MR_FALSE_BREAK_HOLD_FAIL`.
- Signal outputs now carry richer structure diagnostics (`subtype`, `reason_invalid`, and raw quality/penalty fields) to expose why candidates pass/fail.
- Family-selection semantics corrected: when both families are valid, eligibility is represented explicitly (`SETUP_BOTH`) and selection logs show both scores/subtypes with loser reason.
- `BLOCKER_NO_SETUP` remains the dedicated no-signal blocker; no-setup detail now includes family-level invalid reasons.
- Family-specific VWAP handling is materially wider for ORB than MR in filter path, while MR remains stricter on extension rejection.

## v1.5.2 execution preflight reliability fix

- Execution preflight now treats `OrderCheck()==true` with `retcode=0` as acceptable tester success (diagnosed as `ACCEPT_IN_TESTER`) instead of rejecting valid requests.
- Added request price sanitization before preflight/send: real entry snapshot (ask/bid), broker stop-distance enforcement, side-safe stop normalization, TP side repair, and symbol-digit normalization.
- Removed early raw stop-side hard-fail path in favor of sanitize-then-validate behavior (`invalid_stop_side` only if still invalid after repair attempts).
- Pre-send diagnostics now include raw signal prices, snapped entry, final normalized prices, min stop distance, stop/freeze levels, and explicit OrderCheck outcome details.
- OrderCheck request now reuses configured EA magic for consistency with actual sends.

## v1.5.4 expectancy correction hardening

- TREND_CONTINUATION now hard-blocks ordinary MR by default (`TREND_CONTINUATION_DEFAULT_BLOCK`) and only permits rare MR overrides under strict exceptional reclaim criteria (`EXCEPTIONAL_COUNTERTREND_RECLAIM`).
- Payoff gating was rebuilt with realistic slippage estimation (`min(max(2.0, spread*0.15), 8.0)` points) and corrected ORB/MR geometry thresholds to avoid over-pessimistic false rejects while still enforcing structural quality via `BLOCKER_PAYOFF`.
- OR-width continuation allowance is broadened for strong ORB continuation subtypes including `ORB_DIRECT_BREAK`, with wider secondary limit (`primary*1.35`), lower strength floor (`>=65`), and controlled penalty (`-6`).
- Family selection in TREND_CONTINUATION is now continuation-first and deterministic: ORB preferred by default; exceptional MR can override only if it beats ORB by at least 10 score points.
- Management guardrails are simplified and less noisy: BE/trailing remain delayed by bars+MFE thresholds, guard logs are state-change driven, and action logs now include bars, MFE(R), family/subtype, old/new SL, and reason.

## v1.5.6 accepted-trade quality hardening

- Source-level signal geometry now enforces both floor and cap in points before a setup can survive: minimum stop floor, maximum stop cap, cost-thin rejection, and net-R thresholds.
- ORB in `MEAN_REVERSION` is default-blocked; only rare exceptional breakout overrides are allowed under strict subtype/score/net-R/slope conditions.
- Candidate ranking is net-expectancy first (`netRR`, then `netTargetPts`) before score/structure tie-breakers.
- Final pre-send payoff verification runs after normalized prices and rejects degraded requests with `PRE_SEND_PAYOFF_FAIL`.

## v1.5.7 runtime regime/geometry enforcement

- Build identity and runtime startup diagnostics now explicitly report geometry-gate modes (`sourceGeom`, `decisionGeom`, `presendGeom`) under the v1.5.7 build tag.
- Geometry policy is unified through one shared helper used by source construction, decision payoff checks, final selected-candidate validation, and execution pre-send validation.
- ORB in `MEAN_REVERSION` is enforced by hard runtime veto at decision boundary and again before execution when no explicit exceptional override is present.
- ORB quality floor is raised by regime (`TREND_CONTINUATION`/`MIXED`/`MEAN_REVERSION` override) with extra weak-subtype gross/net target requirements to remove cost-thin continuation trades.
- Pre-send logs always print final geometry proof fields (stop/target/spread/slip, grossRR, netTarget, netRR, min required netRR) and DEINIT emits end-of-test quality counters.

## Time assumptions

- Session inputs are interpreted in **broker server time**.
- Defaults are calibrated for XM-style London/NY server-time windows and should be adjusted if broker server offset differs.
- Always validate session alignment on your broker/XM server (including DST changes) before trusting default windows.
