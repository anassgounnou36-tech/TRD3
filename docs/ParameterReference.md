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
- EA init logs now include explicit session timestamps: start, OR end, and trade end for both London and New York windows.
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
- Score internals now also consider subtype quality (ORB/MR), retest/reclaim-window quality, confirmation quality, and level-hold quality.
- Signal diagnostics now include subtype-level validity context (`subtype`, `reason_invalid`, raw trigger/context/extension/structure fields).

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
- Retcode labels use explicit trade-retcode mapping (manual switch) rather than enum string casting.
- Execution failures are categorized for diagnostics: invalid symbol, invalid stop distance, invalid volume, spread violation, market not tradable, order send failed, modify failed.
- Filters are context-first (spread/ATR/session behavior, VWAP/ATR+OR-width, OR-width statistical extremes, compression/chop context), with fixed input limits retained as hard safety caps.
- Filters apply family-specific tolerance: ORB allows more continuation extension (with score penalties), while MR keeps tighter VWAP-extension rejection.
- Family selection exposes explicit both-valid eligibility (`SETUP_BOTH`) while still selecting one trade family by score.
- Blocker diagnostics now include explicit `BLOCKER_NO_SETUP` for true no-signal outcomes.
- Added hard pre-entry payoff gate (points-normalized stop/target/spread/expected slippage): ORB and MR each have minimum target-vs-stop and post-cost net-target requirements, with MR stricter than ORB.
- New blocker class: `BLOCKER_PAYOFF` for structurally weak setup geometry (distinct from score/regime/filter blockers).
- OR-width filter now supports ORB-only secondary allowance in strong TREND_CONTINUATION continuation subtypes (`ORB_TWO_BAR_CONFIRM`, `ORB_BREAK_RETEST_HOLD`, `ORB_BREAK_PAUSE_CONTINUE`) with explicit score penalty.
- Decision logs now include `orb_score_raw/final`, `mr_score_raw/final`, MR trend penalty flag, exceptional MR override flag, OR-width secondary allowance diagnostics, payoff distances, blocker, and selection reason.

## Management state machine (v1.4)

- MGMT_NONE
- MGMT_OPEN
- MGMT_TP1_ARMED
- MGMT_BE_DONE
- MGMT_TRAIL_ACTIVE
- MGMT_TIME_EXIT
- MGMT_COMPLETE
- BE guardrails: >=2 closed M5 bars and MFE thresholds by family (ORB >=1.0R, MR >=1.2R).
- Trail guardrails: >=2 closed M5 bars and >=0.8R MFE.
- Management logs now include `bars_since_entry`, `mfe_r`, action, delay reason, family, and subtype.
