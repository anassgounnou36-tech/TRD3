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
#include <XAUDailyFlow/NoTradeFilter.mqh>
#include <XAUDailyFlow/StrategyDecision.mqh>
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
input bool InpSizeFromEquity = true;

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
XDFNoTradeFilter g_filter;
XDFStrategyDecisionEngine g_decision;
XDFRiskModel g_risk;
XDFExecutionEngine g_exec;
XDFPositionManager g_pm;
XDFDiagnostics g_diag;
XDFCounters g_counters;

datetime g_last_m5_bar=0;
datetime g_last_m1_vwap_bar=0;
datetime g_last_day_anchor=0;
datetime g_last_session_start=0;
XDFSessionId g_prev_session=SESSION_NONE;
XDFSessionId g_current_session=SESSION_NONE;
int g_trades_today=0;
int g_trades_london=0;
int g_trades_ny=0;
string g_last_blocker="";
bool g_daily_blocked=false;
int g_last_score=0;
int g_last_family=SETUP_NONE;
XDFManagementPhase g_mgmt_phase=PHASE_INIT;
datetime g_last_position_opened=0;
bool g_be_moved_for_position=false;
bool g_tp1_seen_for_position=false;

string XDF_PhaseToString(XDFManagementPhase phase)
  {
   if(phase==PHASE_INIT) return("INIT");
   if(phase==PHASE_OPEN) return("OPEN");
   if(phase==PHASE_TP1_REACHED) return("TP1_REACHED");
   if(phase==PHASE_BE_ACTIVE) return("BE_ACTIVE");
   if(phase==PHASE_RUNNER_TRAIL) return("RUNNER_TRAIL");
   if(phase==PHASE_TIME_EXIT) return("TIME_EXIT");
   return("COMPLETE");
  }

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

void XDF_RefreshSessionState(datetime now)
  {
   XDFSessionState computed;
   XDF_InitSessionState(computed);
   XDFSessionId sid=XDF_ActiveSession(now,g_london_cfg,g_ny_cfg,computed);
   g_current_session=sid;

   bool same_session=(sid!=SESSION_NONE && g_prev_session==sid &&
                      g_session_state.session_start==computed.session_start &&
                      g_session_state.day_anchor==computed.day_anchor);

   if(!same_session)
     {
      XDF_InitSessionState(g_session_state);
      g_session_state.day_anchor=computed.day_anchor;
      g_session_state.session_start=computed.session_start;
      g_session_state.or_end=computed.or_end;
      g_session_state.trade_end=computed.trade_end;
      g_session_state.active=computed.active;
      g_session_state.or_complete=computed.or_complete;
      if(sid!=SESSION_NONE)
         g_diag.Log("SESSION_RESET",StringFormat("session=%s start=%s",XDF_SessionToString((int)sid),TimeToString(computed.session_start,TIME_DATE|TIME_MINUTES)));
     }
   else
     {
      g_session_state.day_anchor=computed.day_anchor;
      g_session_state.session_start=computed.session_start;
      g_session_state.or_end=computed.or_end;
      g_session_state.trade_end=computed.trade_end;
      g_session_state.active=computed.active;
      g_session_state.or_complete=(now>=g_session_state.or_end);
     }

   g_prev_session=sid;
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

   if(g_last_position_opened!=ps.opened_at)
     {
      g_last_position_opened=ps.opened_at;
      g_be_moved_for_position=false;
      g_tp1_seen_for_position=false;
      g_mgmt_phase=PHASE_OPEN;
      g_diag.Log("MGMT_PHASE","OPEN");
     }

   double bid=SymbolInfoDouble(g_symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(g_symbol,SYMBOL_ASK);
   double risk=MathAbs(ps.entry-ps.stop);
   double move=(ps.direction>0 ? (bid-ps.entry) : (ps.entry-ask));
   if(!g_tp1_seen_for_position && risk>0.0 && move>=(risk*1.0))
     {
      g_tp1_seen_for_position=true;
      g_mgmt_phase=PHASE_TP1_REACHED;
      g_diag.Log("MGMT_PHASE","TP1_REACHED");
     }

   if(!g_be_moved_for_position && g_pm.ShouldMoveBE(ps,bid,ask,1.0,g_specs.point))
     {
      double be=ps.entry;
      string mod_diag;
      if(ps.direction>0 && ps.stop<be)
        {
         if(g_exec.ModifySLTP(g_symbol,ps.stop,NormalizeDouble(be,g_specs.digits),ps.take_profit,g_specs.point,mod_diag))
           {
            g_be_moved_for_position=true;
            g_mgmt_phase=PHASE_BE_ACTIVE;
            g_diag.Log("MGMT_PHASE","BE_ACTIVE");
           }
          g_diag.Log("BE_MOVE",mod_diag);
        }
      if(ps.direction<0 && ps.stop>be)
        {
         if(g_exec.ModifySLTP(g_symbol,ps.stop,NormalizeDouble(be,g_specs.digits),ps.take_profit,g_specs.point,mod_diag))
           {
            g_be_moved_for_position=true;
            g_mgmt_phase=PHASE_BE_ACTIVE;
            g_diag.Log("MGMT_PHASE","BE_ACTIVE");
           }
          g_diag.Log("BE_MOVE",mod_diag);
        }
     }

   if(g_pm.IsTimedOut(ps,InpMaxHoldMinutes))
     {
      CTrade t;
      g_mgmt_phase=PHASE_TIME_EXIT;
      g_diag.Log("EXIT_TIMEOUT","Closed due to max hold minutes");
      g_diag.Log("MGMT_PHASE","TIME_EXIT");
      if(t.PositionClose(g_symbol))
        {
         g_mgmt_phase=PHASE_COMPLETE;
         g_diag.Log("MGMT_PHASE","COMPLETE");
        }
      return;
     }

   static datetime last_trail_bar=0;
   if(!XDF_NewBar(g_symbol,PERIOD_M5,last_trail_bar))
      return;

   if(atr<=0.0)
      return;

   double trail_dist=atr*0.8;
   double new_sl=ps.stop;
   double min_step=MathMax(g_specs.point*10.0,atr*0.1);
   if(ps.direction>0)
     {
      double candidate=bid-trail_dist;
      if(candidate>ps.stop+min_step)
         new_sl=candidate;
     }
   else
     {
      double candidate=ask+trail_dist;
      if(candidate<ps.stop-min_step)
         new_sl=candidate;
     }

   double old_norm=NormalizeDouble(ps.stop,g_specs.digits);
   double new_norm=NormalizeDouble(new_sl,g_specs.digits);
    if(MathAbs(new_norm-old_norm)>=g_specs.point*5.0)
      {
       string mod_diag;
       if(g_exec.ModifySLTP(g_symbol,ps.stop,new_norm,ps.take_profit,g_specs.point,mod_diag))
          g_mgmt_phase=PHASE_RUNNER_TRAIL;
       g_diag.Log("TRAIL_UPDATE",mod_diag);
      }
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

    g_diag.Log("INIT",StringFormat("symbol=%s resolvedSymbol=%s digits=%d minLot=%.2f serverTime=%s",InpSymbol,g_symbol,g_specs.digits,g_specs.min_lot,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)));
    g_diag.Log("SESSIONS",StringFormat("brokerTime windows London %02d:%02d OR=%d Trade=%d | NewYork %02d:%02d OR=%d Trade=%d",
                                        InpLondonStartHour,InpLondonStartMinute,InpLondonORMinutes,InpLondonTradeMinutes,
                                        InpNYStartHour,InpNYStartMinute,InpNYORMinutes,InpNYTradeMinutes));
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

   XDF_RefreshSessionState(now);

    if(g_current_session==SESSION_NONE)
      {
       g_last_blocker="Out of session";
       XDF_UpdatePanel(g_symbol,g_current_session,false,g_or,0.0,REGIME_NO_TRADE,g_last_family,g_last_score,g_last_blocker,XDF_CurrentSpreadPoints(),has_pos,XDF_DailyPLPct(),g_daily_blocked,XDF_PhaseToString(g_mgmt_phase));
       return;
      }

    if(XDF_InNewsBlock(now))
      {
       g_last_blocker="News block window";
       XDF_UpdatePanel(g_symbol,g_current_session,false,g_or,0.0,REGIME_NO_TRADE,g_last_family,g_last_score,g_last_blocker,XDF_CurrentSpreadPoints(),has_pos,XDF_DailyPLPct(),g_daily_blocked,XDF_PhaseToString(g_mgmt_phase));
       return;
      }

    if(!g_session_state.or_complete)
      {
       g_last_blocker="Building opening range";
       XDF_UpdatePanel(g_symbol,g_current_session,false,g_or,0.0,REGIME_MIXED,g_last_family,g_last_score,g_last_blocker,XDF_CurrentSpreadPoints(),has_pos,XDF_DailyPLPct(),g_daily_blocked,XDF_PhaseToString(g_mgmt_phase));
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
      g_filter.ResetSession();
     }

   if(XDF_NewBar(g_symbol,PERIOD_M1,g_last_m1_vwap_bar) || g_vwap.Value()==0.0)
      g_vwap.Update();

    if(!XDF_NewBar(g_symbol,PERIOD_M5,g_last_m5_bar))
      {
       XDF_UpdatePanel(g_symbol,g_current_session,g_or.valid,g_or,g_vwap.Value(),REGIME_MIXED,g_last_family,g_last_score,g_last_blocker,XDF_CurrentSpreadPoints(),has_pos,XDF_DailyPLPct(),g_daily_blocked,XDF_PhaseToString(g_mgmt_phase));
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

   double m15_slope=g_indicators.M15Slope();
   bool m15_long=g_indicators.M15EMAAligned(true);
   bool m15_short=g_indicators.M15EMAAligned(false);
    string regime_reason;
     XDFRegime regime=g_decision.EvaluateRegime(g_or,atr,g_vwap.Value(),mid,g_session_state.touched_above && g_session_state.touched_below,m15_slope,m15_long,m15_short,regime_reason);
    g_diag.Log("REGIME",StringFormat("regime=%s reason=%s bothSides=%s m15Slope=%.4f m15Long=%s m15Short=%s",
                                     XDF_RegimeToString((int)regime),regime_reason,(g_session_state.touched_above && g_session_state.touched_below)?"Y":"N",
                                     m15_slope,(m15_long?"Y":"N"),(m15_short?"Y":"N")));

     string reject_reason;
     double atr_points=(g_specs.point>0.0 ? atr/g_specs.point : 0.0);
     double recent_range_price=(m5[1].high-m5[1].low);
     double or_width_points=(g_specs.point>0.0 ? g_or.width/g_specs.point : 0.0);
     if(!g_decision.EvaluateBlockers(g_filter,spread_pts,InpMaxSpreadPoints,atr,InpMinATR,atr_points,vwap_dist_pts,InpMaxVWAPDistancePoints,recent_range_price,or_width_points,reject_reason))
      {
       g_counters.setups_rejected++;
       if(reject_reason==g_filter.ReasonSpreadTooHigh()) g_counters.blocked_spread++;
       g_last_blocker=reject_reason;
       XDF_UpdatePanel(g_symbol,g_current_session,g_or.valid,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked,XDF_PhaseToString(g_mgmt_phase));
       return;
      }

    double min_stop_distance=MathMax((double)g_specs.stops_level_points*g_specs.point,g_specs.point*5.0);
    XDFSignal orb;
    XDFSignal mr;
    g_decision.EvaluateSignals(g_symbol,g_or,g_vwap.Value(),atr,g_indicators.EMAAligned(true),g_indicators.EMAAligned(false),min_stop_distance,orb,mr);

    XDFSignal chosen=g_decision.ChooseSignal(orb,mr,regime);

    g_last_family=(int)chosen.family;
    if(!chosen.valid)
      {
       g_last_blocker="BLOCK_REGIME_OR_TRIGGER_MISMATCH";
       g_diag.Log("SETUP_REJECT",StringFormat("family=%d cause=regime_or_trigger_mismatch",(int)chosen.family));
       XDF_UpdatePanel(g_symbol,g_current_session,g_or.valid,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked,XDF_PhaseToString(g_mgmt_phase));
       return;
      }

    XDFScoreBreakdown score=g_decision.EvaluateScore(chosen,g_or,atr,spread_pts,vwap_dist_pts,regime);
    g_last_score=score.total;
    g_counters.setups_scored++;
    g_diag.Log("SCORE",StringFormat("range=%d context=%d trigger=%d exec=%d vwap=%d noise=%d total=%d family=%d",
                                    score.range_quality,score.context_quality,score.trigger_quality,score.execution_quality,
                                    score.vwap_quality,score.noise_penalty,score.total,(int)chosen.family));

   if(!XDF_ScorePasses(regime,score.total))
      {
       g_counters.setups_rejected++;
       g_counters.blocked_score++;
       g_last_blocker="BLOCK_SCORE_BELOW_THRESHOLD";
       g_diag.Log("SETUP_REJECT",StringFormat("family=%d cause=score range=%d context=%d trigger=%d exec=%d vwap=%d noise=%d total=%d",
                                              (int)chosen.family,score.range_quality,score.context_quality,score.trigger_quality,score.execution_quality,score.vwap_quality,score.noise_penalty,score.total));
       XDF_UpdatePanel(g_symbol,g_current_session,g_or.valid,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked,XDF_PhaseToString(g_mgmt_phase));
       return;
      }

    if(g_daily_blocked)
      {
       g_last_blocker="BLOCK_DAILY_GUARD_ACTIVE";
       XDF_UpdatePanel(g_symbol,g_current_session,g_or.valid,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked,XDF_PhaseToString(g_mgmt_phase));
       return;
      }

    if(has_pos)
      {
       g_last_blocker="BLOCK_EXISTING_POSITION";
       XDF_UpdatePanel(g_symbol,g_current_session,g_or.valid,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked,XDF_PhaseToString(g_mgmt_phase));
       return;
      }

    if(g_trades_today>=InpMaxTradesPerDay || XDF_TradesInActiveSession()>=InpMaxTradesPerSession)
      {
       g_last_blocker="BLOCK_TRADE_COUNT_LIMIT";
       XDF_UpdatePanel(g_symbol,g_current_session,g_or.valid,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked,XDF_PhaseToString(g_mgmt_phase));
       return;
      }

   string exec_reason;
    if(!XDF_BasicExecutionChecks(chosen,exec_reason))
      {
       g_last_blocker=exec_reason;
       XDF_UpdatePanel(g_symbol,g_current_session,g_or.valid,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked,XDF_PhaseToString(g_mgmt_phase));
       return;
      }

   bool lot_blocked=false;
   double stop_dist=MathAbs(chosen.entry-chosen.stop);
    double lots=g_risk.CalculateLots(g_specs,InpRiskPct,stop_dist,InpAllowMinLotOverride,lot_blocked,InpSizeFromEquity);
    if(lot_blocked || lots<=0.0)
      {
       g_counters.blocked_risk++;
       g_last_blocker="BLOCK_RISKMODEL_LOT";
       XDF_UpdatePanel(g_symbol,g_current_session,g_or.valid,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked,XDF_PhaseToString(g_mgmt_phase));
       return;
      }

    string exec_diag;
     bool ok=g_exec.Place(g_symbol,chosen,lots,spread_pts,InpMaxSpreadPoints,(int)regime,score.total,exec_diag);
    g_diag.Log("ORDER_ATTEMPT",exec_diag);
   if(ok)
     {
      g_trades_today++;
      XDF_IncSessionTrades();
      g_counters.trades_placed++;
      g_counters.setups_accepted++;
      g_last_blocker="TRADE PLACED";
      g_diag.Log("TRADE",StringFormat("%s score=%d lots=%.2f reason=%s",(chosen.direction>0?"BUY":"SELL"),score.total,lots,chosen.reason));
      g_mgmt_phase=PHASE_OPEN;
     }
   else
     {
      g_last_blocker="Order placement failed";
      g_diag.Log("ORDER_FAIL","Order request failed");
     }

    XDF_UpdatePanel(g_symbol,g_current_session,g_or.valid,g_or,g_vwap.Value(),regime,g_last_family,g_last_score,g_last_blocker,spread_pts,has_pos,XDF_DailyPLPct(),g_daily_blocked,XDF_PhaseToString(g_mgmt_phase));
  }
