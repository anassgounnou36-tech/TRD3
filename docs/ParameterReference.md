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
- Added hard pre-entry payoff gate (points-normalized stop/target/spread/expected slippage) using realistic expected slippage estimate `min(max(2.0, spread*0.15), 8.0)`.
- Payoff minimums (v1.5.4 correction): ORB requires `target >= max(0.75 * stop, 2.0 * spread + slip)` and net target `>= 1.0 * spread`; MR requires `target >= max(1.00 * stop, 2.5 * spread + slip)` and net target `>= 1.25 * spread`.
- v1.5.6 source-level geometry metrics are computed per candidate in points: `stopPts`, `targetPts`, `atrPts`, `orWidthPts`, `spreadPts`, `slipPts`, `grossRR`, `netTargetPts`, `netRR`.
- v1.5.6 ORB geometry gates: stop floor `max(0.22*atrPts, 1.20*spreadPts + 2.0*slipPts)`, stop cap `min(0.95*atrPts, 0.75*orWidthPts + 0.10*atrPts)`, cost-thin/net-R rejects (`netRR` floor family-wide and stricter on weak continuation subtypes).
- v1.5.6 MR geometry gates: stop floor `max(0.28*atrPts, 1.40*spreadPts + 2.0*slipPts)`, stop cap `0.85*atrPts`, cost-thin/net-R rejects (stricter floor on weaker MR subtypes).
- v1.5.6 post-normalization pre-send payoff gate: ORB rejects if final `netRR < 0.90`; MR rejects if final `netRR < 1.00` (`PRE_SEND_PAYOFF_FAIL`).
- v1.5.6 MEAN_REVERSION regime ORB policy: default ORB block with rare exceptional breakout override only under strict subtype/score/net-R/M15 conditions.
- New blocker class: `BLOCKER_PAYOFF` for structurally weak setup geometry (distinct from score/regime/filter blockers).
- OR-width filter now supports ORB-only secondary allowance in strong TREND_CONTINUATION continuation subtypes (`ORB_DIRECT_BREAK`, `ORB_TWO_BAR_CONFIRM`, `ORB_BREAK_RETEST_HOLD`, `ORB_BREAK_PAUSE_CONTINUE`) with wider secondary band (`primary*1.35`) and score penalty `6`.
- Decision logs now include `orb_score_raw/final`, `mr_score_raw/final`, MR block/override reasons, OR-width secondary allowance diagnostics, payoff distances, blocker, and selection reason.
- Internal strategy constants (v1.5.4 correction): MR exceptional score floor `>=80`, ORB acceptable quality gate `>=65`, exceptional MR override margin `>=10` points over ORB, strong-continuation M15 slope-strength gate `>=0.08`.

## Management state machine (v1.4)

- MGMT_NONE
- MGMT_OPEN
- MGMT_TP1_ARMED
- MGMT_BE_DONE
- MGMT_TRAIL_ACTIVE
- MGMT_TIME_EXIT
- MGMT_COMPLETE
- BE guardrails: >=2 closed M5 bars and MFE thresholds by family (ORB >=1.0R, MR >=1.3R).
- Trail guardrails: >=2 closed M5 bars and MFE thresholds by family (ORB >=1.2R, MR >=1.5R).
- Management logs now include `bars_since_entry`, `mfe_r`, action, family, subtype, `oldSL`, `newSL`, reason; guard-delay lines are state-change driven to reduce tick spam.
