#ifndef XAUDAILYFLOW_CHARTPANEL_MQH
#define XAUDAILYFLOW_CHARTPANEL_MQH

#include <XAUDailyFlow/Types.mqh>
#include <XAUDailyFlow/Journal.mqh>

void XDF_UpdatePanel(const string symbol,const string server_time,int session,bool or_built,const XDFOpeningRange &or_data,double vwap,int eligible_family,int selected_family,int score,const string blocker,double spread_points,const string m15_summary,bool has_position,double daily_pl_pct,bool daily_blocked,const string position_state,const string mgmt_state)
  {
   string eligible_text=(eligible_family==SETUP_ORB_CONTINUATION?"ORB":(eligible_family==SETUP_MEAN_REVERSION?"MR":"NONE"));
   string selected_text=(selected_family==SETUP_ORB_CONTINUATION?"ORB":(selected_family==SETUP_MEAN_REVERSION?"MR":"NONE"));
   string txt=StringFormat(
      "XAUDailyFlowEA\nSymbol: %s\nServer Time: %s\nSession: %s\nOR Built: %s\nOR H/L/M/W: %.2f / %.2f / %.2f / %.2f\nVWAP: %.2f\nRegime: %s\nEligible Family: %s\nSelected Family: %s\nSetup Score: %d\nBlocker: %s\nSpread(pts): %.1f\nM15 Context: %s\nPosition State: %s\nManagement State: %s\nHas Position: %s\nDaily P/L%%: %.2f\nDaily Kill-Switch: %s",
      symbol,
      server_time,
      XDF_SessionToString(session),
      (or_built?"YES":"NO"),
      or_data.high,or_data.low,or_data.midpoint,or_data.width,
      vwap,
      XDF_RegimeToString((int)regime),
      eligible_text,
      selected_text,
      score,
      blocker,
      spread_points,
      m15_summary,
      position_state,
      mgmt_state,
      (has_position?"YES":"NO"),
      daily_pl_pct,
      (daily_blocked?"YES":"NO")
   );
   Comment(txt);
  }

#endif
