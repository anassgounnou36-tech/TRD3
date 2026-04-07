# Strategy Rules

## Setup Family A: ORB Continuation

1. Build opening range from first N minutes after session open.
2. Require closed-bar breakout/continuation structure beyond OR boundary.
3. Require non-doji impulse body quality.
4. Confirm by VWAP side and M5 trigger alignment.
5. Reject overextension versus ATR/VWAP distance constraints.
6. Use shared decision helpers (same as EA runtime and BarAudit) so audit/live outcomes remain aligned.
7. ORB subtypes (best valid candidate selected): `ORB_DIRECT_BREAK`, `ORB_BREAK_RETEST_HOLD`, `ORB_TWO_BAR_CONFIRM`, `ORB_BREAK_PAUSE_CONTINUE`.
8. In `TREND_CONTINUATION`, ORB is primary: ordinary MR is hard-blocked by default and may only appear through explicit exceptional-override criteria.

## Setup Family B: Failed OR / VWAP Mean Reversion

1. Detect sweep outside OR boundary with meaningful depth.
2. Require reclaim/failure close behavior back inside OR.
3. Use VWAP and OR midpoint as reversion targets.
4. Prioritize quick intraday exit behavior.
5. Use the same shared signal evaluation path as runtime (no duplicated audit-only signal logic).
6. MR subtypes (best valid candidate selected): `MR_IMMEDIATE_SWEEP_RECLAIM`, `MR_FAILED_BREAK_NEXT_BAR_CONFIRM`, `MR_DELAYED_RECLAIM_WINDOW`, `MR_RECLAIM_THEN_MIDPOINT_CONFIRM`, `MR_FALSE_BREAK_HOLD_FAIL`.
7. In `TREND_CONTINUATION`, MR is default-blocked (`TREND_CONTINUATION_DEFAULT_BLOCK`) and can only override when all exceptional counter-trend reclaim conditions pass, including high score floor and stricter exceptional-payoff check.

## Regime Guidance

- TREND_CONTINUATION: ORB-first priority with explicit selection reasons (`TREND_CONTINUATION_PREFERS_ORB`, `ORB_ONLY_VALID`, `EXCEPTIONAL_MR_OVERRIDE`, `MR_BLOCKED_BY_REGIME`)
- MEAN_REVERSION: favors failed-OR reclaim setups; ORB is default-blocked (`MEAN_REVERSION_DEFAULT_BLOCK`) except rare exceptional breakout override (`EXCEPTIONAL_BREAKOUT_IN_MEAN_REVERSION`)
- MIXED: both families are evaluated and scored; higher-quality valid family is selected under mixed threshold
- NO_TRADE: only for clearly poor conditions

## Filters and blockers (v1.4)

- Spread filter: adaptive versus ATR and local session spread behavior.
- VWAP-distance filter: family-specific behavior (ORB is more tolerant with score penalties; MR remains stricter).
- OR-width guard: adaptive to ATR + recent session OR behavior, with ORB-only secondary width allowance for strong continuation subtypes in TREND_CONTINUATION including `ORB_DIRECT_BREAK` (score-penalized, not free-pass).
- Dead-session/chop guard: includes bar compression/range contraction behavior, not only static ATR floor.
- M15 slope-strength context participates in filter/regime quality gates.
- Blockers are surfaced via stable blocker enums + human-readable reasons in logs/panel.
- `BLOCKER_NO_SETUP` is used for true no-signal cases; `BLOCKER_REGIME` is reserved for actual regime/filter rejections.
- `BLOCKER_PAYOFF` is used when setup geometry fails hard net-payoff requirements after spread/slippage costs.
- If both families are valid, eligibility is represented explicitly (`SETUP_BOTH`) and selection is net-expectancy-first: `netRR`, then `netTargetPts`, then tighter stop in close ties, then score/structure.
- Source-level geometry rejects cost-thin and stop-too-tight/too-wide setups before family selection (family-specific stop floor/cap + net-R requirements).
- Final pre-send payoff verification re-checks normalized stop/target/spread/slippage; degraded requests are rejected as `PRE_SEND_PAYOFF_FAIL`.
- Runtime guardrails enforce regime-family truth at the final boundary: ORB in `MEAN_REVERSION` is vetoed unless explicit exceptional override survives all checks.
- Final selected-candidate geometry validation runs after selection/fallback/filtering; failures are rejected with payoff blocker before execution.

## Trade management phases (v1.4)

- MGMT_NONE → MGMT_OPEN → MGMT_TP1_ARMED → MGMT_BE_DONE → MGMT_TRAIL_ACTIVE → MGMT_TIME_EXIT → MGMT_COMPLETE
- Breakeven is a one-time transition (no repeated attempts), but only after at least 2 fully closed M5 bars and minimum MFE(R) threshold.
- BE thresholds: ORB >=1.0R MFE, MR >=1.3R MFE, both after 2 closed bars.
- Trailing updates require at least 2 fully closed M5 bars and minimum MFE(R): ORB >=1.2R, MR >=1.5R.
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
