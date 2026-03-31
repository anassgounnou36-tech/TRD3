#ifndef XAUDAILYFLOW_SETUPSTATE_MQH
#define XAUDAILYFLOW_SETUPSTATE_MQH

struct XDFCounters
  {
   int sessions_seen;
   int setups_seen;
   int setups_scored;
   int setups_rejected;
   int setups_accepted;
   int trades_placed;
   int blocked_spread;
   int blocked_score;
   int blocked_risk;
  };

#endif
