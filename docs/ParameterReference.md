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

## Execution / Filters
- InpMaxSpreadPoints
- InpMinATR
- InpMaxVWAPDistancePoints
- InpMaxSlippagePoints
- InpMaxHoldMinutes
- InpEnableNewsBlock and block time inputs
- Execution diagnostics include pre-send and post-send trade retcode details
- Execution preflight validates symbol, direction, volume bounds/step, spread, stop distance, trade mode/tradability, and OrderCheck result.
- Execution failures are categorized for diagnostics: invalid symbol, invalid stop distance, invalid volume, spread violation, market not tradable, order send failed, modify failed.
- Filters include adaptive checks (ATR/session-behavior spread, ATR+OR-relative VWAP distance, adaptive OR-width guard, compression dead-session block).
