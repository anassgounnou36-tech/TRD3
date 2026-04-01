# Strategy Rules

## Setup Family A: ORB Continuation

1. Build opening range from first N minutes after session open.
2. Require closed-bar breakout beyond OR boundary.
3. Require non-doji impulse body quality.
4. Confirm by VWAP side and M5 trigger alignment.
5. Reject overextension versus ATR/VWAP distance constraints.
6. Use shared decision helpers (same as EA runtime and BarAudit) so audit/live outcomes remain aligned.

## Setup Family B: Failed OR / VWAP Mean Reversion

1. Detect sweep outside OR boundary with meaningful depth.
2. Require reclaim close back inside OR.
3. Use VWAP and OR midpoint as reversion targets.
4. Prioritize quick intraday exit behavior.
5. Use the same shared signal evaluation path as runtime (no duplicated audit-only signal logic).

## Regime Guidance

- TREND_CONTINUATION: favors ORB continuation
- MEAN_REVERSION: favors failed-OR reclaim setups
- MIXED: both families allowed with stricter score threshold
- NO_TRADE: only for clearly poor conditions

## Filters and blockers (v1.3)

- Spread filter: adaptive versus ATR and local session spread behavior.
- VWAP-distance filter: adaptive versus ATR and OR width context.
- OR-width guard: adaptive to both ATR normalization and recent session OR behavior.
- Dead-session/chop guard: includes bar compression/range contraction behavior, not only static ATR floor.
- Blockers are surfaced directly in logs/panel to clarify rejection cause.

## Trade management phases (v1.3)

- INIT → OPEN → TP1_REACHED → BE_ACTIVE → RUNNER_TRAIL → TIME_EXIT → COMPLETE
- Breakeven is a one-time transition.
- Trailing updates are evaluated on closed M5 bars and only when SL improvement is meaningful.

## Timeframe separation (v1.1)

- **M1:** intraday accumulation (OR + session VWAP)
- **M5:** trigger/entry logic and management cadence
- **M15:** context only (EMA slope + alignment), used by regime engine to bias continuation vs reversion
