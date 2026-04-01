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

## Time assumptions

- Session inputs are interpreted in **broker server time**.
- Defaults are calibrated for XM-style London/NY server-time windows and should be adjusted if broker server offset differs.
