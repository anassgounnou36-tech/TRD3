#property strict
#property description "XAUDailyFlowEA - ORB + VWAP intraday hybrid for XM GOLD aliases"

#include <XAUDailyFlow/Config.mqh>
#include <XAUDailyFlow/Types.mqh>
#include <XAUDailyFlow/SymbolSpecs.mqh>
#include <XAUDailyFlow/TimeWindows.mqh>
#include <XAUDailyFlow/BarUtils.mqh>
#include <XAUDailyFlow/IndicatorEngine.mqh>
#include <XAUDailyFlow/VWAPEngine.mqh>
#include <XAUDailyFlow/OpeningRangeEngine.mqh>
#include <XAUDailyFlow/RegimeEngine.mqh>
#include <XAUDailyFlow/ORBSignal.mqh>
#include <XAUDailyFlow/MeanReversionSignal.mqh>
#include <XAUDailyFlow/SetupScorer.mqh>
#include <XAUDailyFlow/NoTradeFilter.mqh>
#include <XAUDailyFlow/RiskModel.mqh>
#include <XAUDailyFlow/ExecutionEngine.mqh>
#include <XAUDailyFlow/PositionManager.mqh>
#include <XAUDailyFlow/SetupState.mqh>
#include <XAUDailyFlow/Diagnostics.mqh>
#include <XAUDailyFlow/Journal.mqh>
#include <XAUDailyFlow/ChartPanel.mqh>
#include <Trade/Trade.mqh>

input string InpSymbol = "";

input int InpLondonStartHour = 8;
input int InpLondonStartMinute = 0;
input int InpLondonORMinutes = 10;
input int InpLondonTradeMinutes = 120;

input int InpNYStartHour = 13;
input int InpNYStartMinute = 30;
input int InpNYORMinutes = 10;
input int InpNYTradeMinutes = 120;

input double InpRiskPct = 0.35;
input double InpMaxDailyLossPct = 1.8;
input int InpMaxTradesPerDay = 6;
input int InpMaxTradesPerSession = 3;
input bool InpEnableDailyProfitLock = true;
input double InpDailyProfitLockR = 3.0;
input bool InpAllowMinLotOverride = false;

input int InpMinSetupScore = 58;
input int InpMixedModeScoreThreshold = 63;
input int InpConflictOverrideScoreThreshold = 75;

input double InpMaxSpreadPoints = 55.0;
input double InpMinATR = 1.2;
input double InpMaxVWAPDistancePoints = 420.0;
input int InpMaxSlippagePoints = XDF_MAX_SLIPPAGE_POINTS_DEFAULT;
input int InpMaxHoldMinutes = 75;
input bool InpEnableFileLogging = true;

input bool InpEnableNewsBlock = false;
input int InpNewsBlockStartHour = 0;
input int InpNewsBlockStartMinute = 0;
input int InpNewsBlockEndHour = 0;
input int InpNewsBlockEndMinute = 0;

string g_symbol;
XDFSymbolSpecs g_specs;
XDFSessionConfig g_london_cfg;
XDFSessionConfig g_ny_cfg;
XDFSessionState g_session_state;
XDFOpeningRange g_or;

XDFIndicatorEngine g_indicators;
XDFVWAPEngine g_vwap;
XDFOpeningRangeEngine g_or_engine;
XDFRegimeEngine g_regime;
XDFORBSignal g_orb_signal;
XDFMeanReversionSignal g_mr_signal;
XDFSetupScorer g_scorer;
XDFNoTradeFilter g_filter;
XDFRiskModel g_risk;
XDFExecutionEngine g_exec;
XDFPositionManager g_pm;
XDFDiagnostics g_diag;
XDFCounters g_counters;

datetime g_last_m5_bar=0;
datetime g_last_m1_vwap_bar=0;
datetime g_last_day_anchor=0;
datetime g_last_session_start=0;
XDFSessionId g_current_session=SESSION_NONE;
int g_trades_today=0;
int g_trades_london=0;
int g_trades_ny=0;
string g_last_blocker="";
bool g_daily_blocked=false;
int g_last_score=0;
int g_last_family=SETUP_NONE;

double XDF_DailyPLPct()
  {
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal<=0.0)
      return(0.0);
   return((AccountInfoDouble(ACCOUNT_EQUITY)-bal)/bal*100.0);
  }

double XDF_CurrentSpreadPoints()
  {
   double ask=SymbolInfoDouble(g_symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(g_symbol,SYMBOL_BID);
   return((ask-bid)/g_specs.point);
  }

bool XDF_InNewsBlock(datetime now)
  {
   if(!InpEnableNewsBlock)
      return(false);
   datetime day=XDF_DayAnchor(now);
   datetime st=day + InpNewsBlockStartHour*3600 + InpNewsBlockStartMinute*60;
   datetime en=day + InpNewsBlockEndHour*3600 + InpNewsBlockEndMinute*60;
   if(en<st)
      return(now>=st || now<=en);
   return(now>=st && now<=en);
  }

int XDF_TradesInActiveSession()
  {
   if(g_current_session==SESSION_LONDON)
      return(g_trades_london);
   if(g_current_session==SESSION_NEWYORK)
      return(g_trades_ny);
   return(0);
  }

void XDF_IncSessionTrades()
  {
   if(g_current_session==SESSION_LONDON)
      g_trades_london++;
   else if(g_current_session==SESSION_NEWYORK)
      g_trades_ny++;
  }

void XDF_ResetDayCounters(datetime now)
  {
   datetime anchor=XDF_DayAnchor(now);
   if(anchor!=g_last_day_anchor)
     {
      g_last_day_anchor=anchor;
      g_trades_today=0;
      g_trades_london=0;
      g_trades_ny=0;
      g_daily_blocked=false;
      g_risk.StartDay(AccountInfoDouble(ACCOUNT_EQUITY));
      g_diag.Log("NEW_DAY",TimeToString(anchor,TIME_DATE));
     }
  }

bool XDF_ScorePasses(XDFRegime regime,int score)
  {
   if(regime==REGIME_NO_TRADE)
      return(false);
   if(regime==REGIME_MIXED)
      return(score>=InpMixedModeScoreThreshold);
   return(score>=InpMinSetupScore);
  }

bool XDF_BasicExecutionChecks(const XDFSignal &sig,string &reason)
  {
   reason="";
   if(sig.stop<=0.0)
     {
      reason="Invalid stop";
      return(false);
     }

   double min_dist=g_specs.stops_level_points*g_specs.point;
   if(min_dist>0.0)
     {
      if(sig.direction>0 && (sig.entry-sig.stop)<min_dist)
        {
         reason="Stop level constraint";
         return(false);
        }
      if(sig.direction<0 && (sig.stop-sig.entry)<min_dist)
        {
         reason="Stop level constraint";
         return(false);
        }
     }
   return(true);
  }

void XDF_ManageOpenPosition(double atr)
  {
   XDFPositionState ps;
   if(!g_pm.Read(g_symbol,ps))
      return;

   double bid=SymbolInfoDouble(g_symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(g_symbol,SYMBOL_ASK);

   if(g_pm.ShouldMoveBE(ps,bid,ask,1.0))
     {
      double be=ps.entry;
      if(ps.direction>0 && ps.stop<be)
         g_exec.ModifySLTP(g_symbol,NormalizeDouble(be,g_specs.digits),ps.take_profit);
      if(ps.direction<0 && ps.stop>be)
         g_exec.ModifySLTP(g_symbol,NormalizeDouble(be,g_specs.digits),ps.take_profit);
     }

   if(g_pm.IsTimedOut(ps,InpMaxHoldMinutes))
     {
      CTrade t;
      t.PositionClose(g_symbol);
      g_diag.Log("EXIT_TIMEOUT","Closed due to max hold minutes");
      return;
     }

   static datetime last_trail_bar=0;
   if(!XDF_NewBar(g_symbol,PERIOD_M5,last_trail_bar))
      return;

   if(atr<=0.0)
      return;

   double trail_dist=atr*0.8;
   double new_sl=ps.stop;
   if(ps.direction>0)
     {
      double candidate=bid-trail_dist;
      if(candidate>ps.stop+atr*0.2)
         new_sl=candidate;
     }
   else
     {
      double candidate=ask+trail_dist;
      if(candidate<ps.stop-atr*0.2)
         new_sl=candidate;
     }

   if(new_sl!=ps.stop)
      g_exec.ModifySLTP(g_symbol,NormalizeDouble(new_sl,g_specs.digits),ps.take_profit);
  }

int OnInit()
  {
   g_symbol=XDF_ResolveSymbol(InpSymbol);
   if(!SymbolSelect(g_symbol,true))
     {
      Print("XAUDailyFlowEA: failed to select symbol ",g_symbol);
      return(INIT_FAILED);
     }

   if(!XDF_LoadSymbolSpecs(g_symbol,g_specs))
     {
      Print("XAUDailyFlowEA: failed to load symbol specs");
      return(INIT_FAILED);
     }

   if(!g_indicators.Init(g_symbol))
     {
      Print("XAUDailyFlowEA: indicator init failed");
      return(INIT_FAILED);
     }

   g_london_cfg.start_hour=InpLondonStartHour;
   g_london_cfg.start_minute=InpLondonStartMinute;
   g_london_cfg.or_minutes=InpLondonORMinutes;
   g_london_cfg.trade_minutes=InpLondonTradeMinutes;
   g_london_cfg.id=SESSION_LONDON;
   g_london_cfg.name="London";

   g_ny_cfg.start_hour=InpNYStartHour;
   g_ny_cfg.start_minute=InpNYStartMinute;
   g_ny_cfg.or_minutes=InpNYORMinutes;
   g_ny_cfg.trade_minutes=InpNYTradeMinutes;
   g_ny_cfg.id=SESSION_NEWYORK;
   g_ny_cfg.name="NewYork";

   g_or_engine.Init(g_symbol);
   g_exec.Configure(g_symbol,XDF_MAGIC,InpMaxSlippagePoints);
   g_diag.Init(InpEnableFileLogging);
   g_risk.StartDay(AccountInfoDouble(ACCOUNT_EQUITY));
   ZeroMemory(g_counters);

   g_diag.Log("INIT",StringFormat("symbol=%s digits=%d minLot=%.2f",g_symbol,g_specs.digits,g_specs.min_lot));
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   g_indicators.Release();
   g_diag.Log("DEINIT",StringFormat("reason=%d",reason));
   g_diag.Shutdown();
   Comment("");
  }

void OnTick()
  {
   datetime now=TimeCurrent();
   XDF_ResetDayCounters(now);

   if(g_risk.DailyLossHit(AccountInfoDouble(ACCOUNT_EQUITY),InpMaxDailyLossPct))
     {
      g_daily_blocked=true;
      g_last_blocker="Daily loss cap";
     }

   if(InpEnableDailyProfitLock && g_risk.DailyProfitLockHit(AccountInfoDouble(ACCOUNT_EQUITY),InpDailyProfitLockR,InpRiskPct))
     {
      g_daily_blocked=true;
      g_last_blocker="Daily profit lock";
     }

   XDFPositionState ps;
   bool has_pos=g_pm.Read(g_symbol,ps);

   double atr=g_indicators.ATR();
   if(has_pos)
      XDF_ManageOpenPosition(atr);

   g_current_session=XDF_ActiveSession(now,g_london_cfg,g_ny_cfg,g_session_state);

   if(g_current_session==SESSION_NONE)
     {
      g_last_blocker="Out of session";
      XDF_UpdatePanel(g_symbol,g_current_session,g_or,0.0,REGIME_NO_TRADE,g_last_family,g_last_score,g_last_blocker,XDF_CurrentSpreadPoints(),has_pos,XDF_DailyPLPct(),g_daily_blocked);
      return;
     }

   if(XDF_InNewsBlock(now))
     {
      g_last_blocker="News block window";
      XDF_UpdatePanel(g_symbol,g_current_session,g_or,0.0,REGIME_NO_TRADE,g_last_family,g_last_score,g_last_blocker,XDF_CurrentSpreadPoints(),has_pos,XDF_DailyPLPct(),g_daily_blocked);
      return;
     }

   if(g_session_state.session_start!=0 && now<g_session_state.or_end)
     {
      g_last_blocker="Building opening range";
      XDF_UpdatePanel(g_symbol,g_current_session,g_or,0.0,REGIME_MIXED,g_last_family,g_last_score,g_last_blocker,XDF_CurrentSpreadPoints(),has_pos,XDF_DailyPLPct(),g_daily_blocked);
      return;
     }

   if(!g_or_engine.Build(g_session_state.session_start,g_session_state.or_end,g_or))
     {
      g_last_blocker="OR unavailable";
      return;
     }

   if(g_session_state.session_start!=g_last_session_start)
     {
      g_vwap.Reset(g_symbol,g_session_state.session_start);
      g_last_session_start=g_session_state.session_start;
      g_last_m1_vwap_bar=0;
     }

   if(XDF_NewBar(g_symbol,PERIOD_M1,g_last_m1_vwap_bar) || g_vwap.Value()==0.0)
      g_vwap.Update();

   if(!XDF_NewBar(g_symbol,PERIOD_M5,g_last_m5_bar))
     {
      XDF_UpdatePanel(g_symbol,g_current_session,g_or,g_vwap.Value(),REGIME_MIXED,g_last_family,g_last_score,g_last_blocker,XDF_CurrentSpreadPoints(),has_pos,XDF_DailyPLPct(),g_daily_blocked);
      return;
     }

   g_counters.setups_seen++;

   MqlRates m5[3];
   ArraySetAsSeries(m5,true);
   CopyRates(g_symbol,PERIOD_M5,0,3,m5);
   if(m5[1].high>g_or.high) g_session_state.touched_above=true;
   if(m5[1].low<g_or.low) g_session_state.touched_below=true;

   double bid=SymbolInfoDouble(g_symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(g_symbol,SYMBOL_ASK);
   double mid=(bid+ask)/2.0;
   double spread_pts=XDF_CurrentSpreadPoints();
   double vwap_dist_pts=g_vwap.DistanceInPoints(mid,g_specs.point);

   XDFRegime regime=g_regime.Detect(g_or,atr,g_vwap.Value(),mid,g_session_state.touched_above && g_session_state.touched_below,0.0);

   string reject_reason;
   if(!g_filter.Allow(spread_pts,InpMaxSpreadPoints,atr,InpMinATR,vwap_dist_pts,InpMaxVWAPDistancePoints,reject_reason))
     {
      g_counters.setups_rejected++;
      if(reject_reason=="Spread too high") g_counters.blocked_spread++;
      g_last_blocker=reject_reason;
      XDF_UpdatePanel(g_symbol,g_current_session,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked);
      return;
     }

   double min_stop_distance=MathMax((double)g_specs.stops_level_points*g_specs.point,g_specs.point*5.0);
   XDFSignal orb=g_orb_signal.Evaluate(g_symbol,g_or,g_vwap.Value(),atr,g_indicators.EMAAligned(true),g_indicators.EMAAligned(false),min_stop_distance);
   XDFSignal mr=g_mr_signal.Evaluate(g_symbol,g_or,g_vwap.Value(),atr);

   XDFSignal chosen;
   ZeroMemory(chosen);
   if(orb.valid && mr.valid)
      chosen=(regime==REGIME_MEAN_REVERSION ? mr : orb);
   else if(orb.valid)
      chosen=orb;
   else if(mr.valid)
      chosen=mr;

   g_last_family=(int)chosen.family;
   if(!chosen.valid)
     {
      g_last_blocker="No qualified setup";
      XDF_UpdatePanel(g_symbol,g_current_session,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked);
      return;
     }

   XDFScoreBreakdown score=g_scorer.Score(chosen,g_or,atr,spread_pts,vwap_dist_pts,regime);
   g_last_score=score.total;
   g_counters.setups_scored++;

   if(!XDF_ScorePasses(regime,score.total))
     {
      g_counters.setups_rejected++;
      g_counters.blocked_score++;
      g_last_blocker="Score below threshold";
      XDF_UpdatePanel(g_symbol,g_current_session,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked);
      return;
     }

   if(g_daily_blocked)
     {
      g_last_blocker="Daily blocker active";
      XDF_UpdatePanel(g_symbol,g_current_session,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked);
      return;
     }

   if(has_pos)
     {
      g_last_blocker="Existing position";
      XDF_UpdatePanel(g_symbol,g_current_session,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked);
      return;
     }

   if(g_trades_today>=InpMaxTradesPerDay || XDF_TradesInActiveSession()>=InpMaxTradesPerSession)
     {
      g_last_blocker="Trade count limit";
      XDF_UpdatePanel(g_symbol,g_current_session,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked);
      return;
     }

   string exec_reason;
   if(!XDF_BasicExecutionChecks(chosen,exec_reason))
     {
      g_last_blocker=exec_reason;
      XDF_UpdatePanel(g_symbol,g_current_session,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked);
      return;
     }

   bool lot_blocked=false;
   double stop_dist=MathAbs(chosen.entry-chosen.stop);
   double lots=g_risk.CalculateLots(g_specs,InpRiskPct,stop_dist,InpAllowMinLotOverride,lot_blocked);
   if(lot_blocked || lots<=0.0)
     {
      g_counters.blocked_risk++;
      g_last_blocker="Lot blocked by risk model";
      XDF_UpdatePanel(g_symbol,g_current_session,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked);
      return;
     }

   bool ok=g_exec.Place(g_symbol,chosen,lots);
   if(ok)
     {
      g_trades_today++;
      XDF_IncSessionTrades();
      g_counters.trades_placed++;
      g_counters.setups_accepted++;
      g_last_blocker="TRADE PLACED";
      g_diag.Log("TRADE",StringFormat("%s score=%d lots=%.2f reason=%s",(chosen.direction>0?"BUY":"SELL"),score.total,lots,chosen.reason));
     }
   else
     {
      g_last_blocker="Order placement failed";
      g_diag.Log("ORDER_FAIL","Order request failed");
     }

   XDF_UpdatePanel(g_symbol,g_current_session,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked);
  }
