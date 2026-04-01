# Parameter Reference

## Sessions
- InpLondonStartHour / InpLondonStartMinute
- InpLondonORMinutes
- InpLondonTradeMinutes
- InpNYStartHour / InpNYStartMinute
- InpNYORMinutes
- InpNYTradeMinutes
- Note: all session times use broker server time
- EA init logs configured London/NY windows, current server time, and resolved trade symbol; tune windows to your broker server offset (XM may differ by server/DST).
- OR construction uses exact M1 bar shifts with deterministic boundaries (start inclusive, OR-end exclusive).

## Risk
- InpRiskPct
- InpMaxDailyLossPct
- InpMaxTradesPerDay
- InpMaxTradesPerSession
- InpEnableDailyProfitLock
- InpDailyProfitLockR
- InpAllowMinLotOverride
- InpSizeFromEquity (default true; if false sizing uses account balance)

## Scoring
- InpMinSetupScore
- InpMixedModeScoreThreshold
- InpConflictOverrideScoreThreshold
- Score breakdown is logged per setup (range/context/trigger/execution/vwap/noise/total)
- InpMinSetupScore: baseline threshold for non-MIXED regimes.
- InpMixedModeScoreThreshold: stricter threshold while regime is MIXED.
- Score components are context-aware (including execution quality, VWAP alignment quality, and noise penalties).
- M15 context contributes through trend alignment and slope-strength weighting.

## Execution / Filters
- InpMaxSpreadPoints
- InpMinATR
- InpMaxVWAPDistancePoints
- InpMaxSlippagePoints
- InpMaxHoldMinutes
- InpEnableNewsBlock and block time inputs
- Execution diagnostics include pre-send and post-send trade retcode details
- Execution preflight validates symbol, direction, volume bounds/step, spread, stop distance, trade mode/tradability, and OrderCheck result.
- Preflight request snapshot includes: deviation, trade mode, fill mode, volume min/max/step, spread, stop/target distance, family/regime/score.
- Execution failures are categorized for diagnostics: invalid symbol, invalid stop distance, invalid volume, spread violation, market not tradable, order send failed, modify failed.
- Filters are context-first (spread/ATR/session behavior, VWAP/ATR+OR-width, OR-width statistical extremes, compression/chop context), with fixed input limits retained as hard safety caps.

## Management state machine (v1.4)

- MGMT_NONE
- MGMT_OPEN
- MGMT_TP1_ARMED
- MGMT_BE_DONE
- MGMT_TRAIL_ACTIVE
- MGMT_TIME_EXIT
- MGMT_COMPLETE
