# Walk-Forward Protocol

1. Use XM GOLD historical data with realistic spread/slippage assumptions.
2. Start with `GOLD_XM_Balanced.set` for baseline.
3. Validate monthly behavior goals:
   - materially higher activity than low-frequency selective bot
   - intraday hold profile
   - no order spam
4. Run conservative and aggressive variants to map risk-frequency envelope.
5. Reject settings that produce frozen no-trade behavior under normal month conditions.
