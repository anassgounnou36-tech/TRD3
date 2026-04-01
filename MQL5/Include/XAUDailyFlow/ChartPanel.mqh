#ifndef XAUDAILYFLOW_CHARTPANEL_MQH
#define XAUDAILYFLOW_CHARTPANEL_MQH

#include <XAUDailyFlow/Types.mqh>
#include <XAUDailyFlow/Journal.mqh>

void XDF_UpdatePanel(const string symbol,int session,bool or_built,const XDFOpeningRange &or_data,double vwap,int regime,int family,int score,const string blocker,double spread_points,bool has_position,double daily_pl_pct,bool daily_blocked,const string position_state)
  {
   string family_text=(family==SETUP_ORB_CONTINUATION?"ORB":(family==SETUP_MEAN_REVERSION?"MR":"NONE"));
   string txt=StringFormat(
      "XAUDailyFlowEA\nSymbol: %s\nSession: %s\nOR Built: %s\nOR H/L/M: %.2f / %.2f / %.2f\nVWAP: %.2f\nRegime: %s\nSetup Candidate: %s\nSetup Score: %d\nBlocker: %s\nSpread(pts): %.1f\nPosition State: %s\nHas Position: %s\nDaily P/L%%: %.2f\nDaily Kill-Switch: %s",
      symbol,
      XDF_SessionToString(session),
      (or_built?"YES":"NO"),
      or_data.high,or_data.low,or_data.midpoint,
      vwap,
      XDF_RegimeToString(regime),
      family_text,
      score,
      blocker,
      spread_points,
      position_state,
      (has_position?"YES":"NO"),
      daily_pl_pct,
      (daily_blocked?"YES":"NO")
   );
   Comment(txt);
  }

#endif
