# XAUDailyFlowEA Bot Specification

XAUDailyFlowEA is a pure MQL5 intraday bot for XM GOLD aliases (GOLD/XAUUSD/XAUUSDm/XAUUSD.*). It is a session-based daily-opportunity engine that combines:

- Opening Range Breakout continuation (ORB)
- Failed OR / VWAP mean reversion

## Core principles

- M1 data for OR/VWAP calculations
- M5 for setup qualification and execution cycle
- Optional M15 context approximated via regime inputs
- London and New York windows only
- No overnight hold and no swing bias
- Market execution only
- Strict daily loss and trade count controls
