# Strategy Rules

## Setup Family A: ORB Continuation

1. Build opening range from first N minutes after session open.
2. Require closed-bar breakout/continuation structure beyond OR boundary.
3. Require non-doji impulse body quality.
4. Confirm by VWAP side and M5 trigger alignment.
5. Reject overextension versus ATR/VWAP distance constraints.
6. Use shared decision helpers (same as EA runtime and BarAudit) so audit/live outcomes remain aligned.
7. ORB subtypes (best valid candidate selected): `ORB_DIRECT_BREAK`, `ORB_BREAK_RETEST_HOLD`, `ORB_TWO_BAR_CONFIRM`, `ORB_BREAK_PAUSE_CONTINUE`.
8. In `TREND_CONTINUATION`, ORB is primary: if both families are eligible, ORB is selected by regime priority unless MR passes explicit exceptional-override rules.

## Setup Family B: Failed OR / VWAP Mean Reversion

1. Detect sweep outside OR boundary with meaningful depth.
2. Require reclaim/failure close behavior back inside OR.
3. Use VWAP and OR midpoint as reversion targets.
4. Prioritize quick intraday exit behavior.
5. Use the same shared signal evaluation path as runtime (no duplicated audit-only signal logic).
6. MR subtypes (best valid candidate selected): `MR_IMMEDIATE_SWEEP_RECLAIM`, `MR_FAILED_BREAK_NEXT_BAR_CONFIRM`, `MR_DELAYED_RECLAIM_WINDOW`, `MR_RECLAIM_THEN_MIDPOINT_CONFIRM`, `MR_FALSE_BREAK_HOLD_FAIL`.
7. In `TREND_CONTINUATION`, MR is down-ranked by fixed score penalty and can only override ORB when subtype and score/structure/payoff conditions satisfy exceptional counter-trend criteria.

## Regime Guidance

- TREND_CONTINUATION: ORB-first priority with hard family-preference reasons in logs (e.g., `REGIME_PREFERS_ORB`, `EXCEPTIONAL_MR_OVERRIDE`)
- MEAN_REVERSION: favors failed-OR reclaim setups
- MIXED: both families are evaluated and scored; higher-quality valid family is selected under mixed threshold
- NO_TRADE: only for clearly poor conditions

## Filters and blockers (v1.4)

- Spread filter: adaptive versus ATR and local session spread behavior.
- VWAP-distance filter: family-specific behavior (ORB is more tolerant with score penalties; MR remains stricter).
- OR-width guard: adaptive to ATR + recent session OR behavior, with ORB-only secondary width allowance for strong continuation subtypes in TREND_CONTINUATION (score-penalized, not free-pass).
- Dead-session/chop guard: includes bar compression/range contraction behavior, not only static ATR floor.
- M15 slope-strength context participates in filter/regime quality gates.
- Blockers are surfaced via stable blocker enums + human-readable reasons in logs/panel.
- `BLOCKER_NO_SETUP` is used for true no-signal cases; `BLOCKER_REGIME` is reserved for actual regime/filter rejections.
- `BLOCKER_PAYOFF` is used when setup geometry fails hard net-payoff requirements after spread/slippage costs.
- If both families are valid, eligibility is represented explicitly (`SETUP_BOTH`) and selection is score-based with subtype-level loser reason logging.

## Trade management phases (v1.4)

- MGMT_NONE → MGMT_OPEN → MGMT_TP1_ARMED → MGMT_BE_DONE → MGMT_TRAIL_ACTIVE → MGMT_TIME_EXIT → MGMT_COMPLETE
- Breakeven is a one-time transition (no repeated attempts), but only after at least 2 fully closed M5 bars and minimum MFE(R) threshold.
- BE thresholds: ORB >=1.0R MFE, MR >=1.2R MFE, both after 2 closed bars.
- Trailing updates require at least 2 fully closed M5 bars and >=0.8R MFE before any trail attempt.
- BE and trail are guarded so they do not fire together in the same tick except when guardrails first permit a single action.

## Opening range determinism (v1.4)

- OR is built from exact M1 bar shifts, not ambiguous time-range inclusivity.
- Inclusion rule: session-start bar included; first bar at OR-end excluded.
- OR diagnostics report start/end, shift span, bar count, and computed OR values.

## Context parity (v1.4.1)

- EA runtime and BarAudit context inputs are built through the same shared context-builder module.
- Shared context includes OR snapshot, session touches/state, VWAP state, spread/ATR inputs, and full M15 context object.
- Objective: same symbol/time/session config should produce matching decision inputs across live/audit paths.

## Timeframe separation (v1.1)

- **M1:** intraday accumulation (OR + session VWAP)
- **M5:** trigger/entry logic and management cadence
- **M5:** timestamp-aligned closed-bar windows are used for both live and audit signal evaluation
- **M15:** context only (EMA slope + alignment), used by regime engine to bias continuation vs reversion
