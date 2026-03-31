# Parameter Reference

## Sessions
- InpLondonStartHour / InpLondonStartMinute
- InpLondonORMinutes
- InpLondonTradeMinutes
- InpNYStartHour / InpNYStartMinute
- InpNYORMinutes
- InpNYTradeMinutes
- Note: all session times use broker server time

## Risk
- InpRiskPct
- InpMaxDailyLossPct
- InpMaxTradesPerDay
- InpMaxTradesPerSession
- InpEnableDailyProfitLock
- InpDailyProfitLockR
- InpAllowMinLotOverride

## Scoring
- InpMinSetupScore
- InpMixedModeScoreThreshold
- InpConflictOverrideScoreThreshold
- Score breakdown is logged per setup (range/context/trigger/execution/vwap/noise/total)

## Execution / Filters
- InpMaxSpreadPoints
- InpMinATR
- InpMaxVWAPDistancePoints
- InpMaxSlippagePoints
- InpMaxHoldMinutes
- InpEnableNewsBlock and block time inputs
- Execution diagnostics include pre-send and post-send trade retcode details
