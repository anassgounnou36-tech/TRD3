# Strategy Rules

## Setup Family A: ORB Continuation

1. Build opening range from first N minutes after session open.
2. Require closed-bar breakout beyond OR boundary.
3. Require non-doji impulse body quality.
4. Confirm by VWAP side and EMA alignment.
5. Reject overextension versus ATR/VWAP distance constraints.

## Setup Family B: Failed OR / VWAP Mean Reversion

1. Detect sweep outside OR boundary with meaningful depth.
2. Require reclaim close back inside OR.
3. Use VWAP and OR midpoint as reversion targets.
4. Prioritize quick intraday exit behavior.

## Regime Guidance

- TREND_CONTINUATION: favors ORB continuation
- MEAN_REVERSION: favors failed-OR reclaim setups
- MIXED: both families allowed with stricter score threshold
- NO_TRADE: only for clearly poor conditions
