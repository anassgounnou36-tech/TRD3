#property strict
#property description "XAUDailyFlowEA - ORB + VWAP intraday hybrid for XM GOLD aliases"

#include <XAUDailyFlow/Config.mqh>
#include <XAUDailyFlow/Types.mqh>
#include <XAUDailyFlow/SymbolSpecs.mqh>
#include <XAUDailyFlow/TimeWindows.mqh>
#include <XAUDailyFlow/SessionState.mqh>
#include <XAUDailyFlow/BarUtils.mqh>
#include <XAUDailyFlow/IndicatorEngine.mqh>
#include <XAUDailyFlow/VWAPEngine.mqh>
#include <XAUDailyFlow/OpeningRangeEngine.mqh>
#include <XAUDailyFlow/ContextBuilder.mqh>
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
XDFSessionRuntimeState g_runtime_session;
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
string g_last_or_build_signature="";
string g_last_or_validate_signature="";
int g_trades_today=0;
XDFBlockerInfo g_last_blocker;
bool g_daily_blocked=false;
int g_last_score=0;
int g_last_regime=REGIME_NO_TRADE;
int g_last_eligible_family=SETUP_NONE;
int g_last_selected_family=SETUP_NONE;
XDFMgmtState g_mgmt_state=MGMT_NONE;
datetime g_last_position_opened=0;
bool g_be_moved_for_position=false;
bool g_tp1_seen_for_position=false;
const double XDF_BE_MFE_ORB_R=1.0;
const double XDF_BE_MFE_MR_R=1.2;
const double XDF_TRAIL_MFE_R=0.8;

int XDF_BarsSinceEntryM5(const datetime opened_at)
  {
   if(opened_at<=0)
      return(0);
   int shift=iBarShift(g_symbol,PERIOD_M5,opened_at,false);
   if(shift<=0)
      return(0);
   return(shift-1);
  }

double XDF_MFER(const XDFPositionState &ps,const double risk)
  {
   if(risk<=0.0)
      return(0.0);
   int open_shift=iBarShift(g_symbol,PERIOD_M5,ps.opened_at,false);
   if(open_shift<0)
      return(0.0);
   int bars=open_shift+1;
   if(bars<1)
      bars=1;
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int copied=CopyRates(g_symbol,PERIOD_M5,0,bars,rates);
   if(copied<=0)
      return(0.0);
   double best=0.0;
   for(int i=0;i<copied;i++)
     {
      double favorable=(ps.direction>0?(rates[i].high-ps.entry):(ps.entry-rates[i].low));
      if(favorable>best)
         best=favorable;
     }
   return(best/risk);
  }

string XDF_MgmtStateToString(XDFMgmtState phase)
  {
   if(phase==MGMT_NONE) return("NONE");
   if(phase==MGMT_OPEN) return("OPEN");
   if(phase==MGMT_TP1_ARMED) return("TP1_ARMED");
   if(phase==MGMT_BE_DONE) return("BE_DONE");
   if(phase==MGMT_TRAIL_ACTIVE) return("TRAIL_ACTIVE");
   if(phase==MGMT_TIME_EXIT) return("TIME_EXIT");
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
   return(g_runtime_session.session_trade_count);
  }

void XDF_IncSessionTrades()
  {
   g_runtime_session.session_trade_count++;
  }

void XDF_ResetDayCounters(datetime now)
  {
   datetime anchor=XDF_DayAnchor(now);
   if(anchor!=g_last_day_anchor)
     {
       g_last_day_anchor=anchor;
       g_trades_today=0;
       g_daily_blocked=false;
       g_risk.StartDay(AccountInfoDouble(ACCOUNT_EQUITY));
       XDF_ResetForNewDay(g_runtime_session,anchor);
       g_diag.Log("NEW_DAY",TimeToString(anchor,TIME_DATE));
      }
  }

void XDF_RefreshSessionState(datetime now)
  {
   XDFSessionState computed;
   XDF_InitSessionState(computed);
   XDFSessionId sid=XDF_ActiveSession(now,g_london_cfg,g_ny_cfg,computed);
   bool same_session=XDF_IsSameActiveSession(g_runtime_session,sid,computed);

   if(!same_session)
     {
      XDF_InitSessionState(g_session_state);
      g_session_state.day_anchor=computed.day_anchor;
      g_session_state.session_start=computed.session_start;
      g_session_state.or_end=computed.or_end;
      g_session_state.trade_end=computed.trade_end;
      g_session_state.active=computed.active;
      g_session_state.or_complete=computed.or_complete;
      XDF_ResetForNewSession(g_runtime_session,sid,computed);
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
      g_runtime_session.or_complete=g_session_state.or_complete;
     }
   g_runtime_session.current_session=sid;
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
      g_mgmt_state=MGMT_OPEN;
      g_diag.Log("MGMT_PHASE","MGMT_OPEN");
     }

    double bid=SymbolInfoDouble(g_symbol,SYMBOL_BID);
    double ask=SymbolInfoDouble(g_symbol,SYMBOL_ASK);
    double risk=MathAbs(ps.entry-ps.stop);
    double move=(ps.direction>0 ? (bid-ps.entry) : (ps.entry-ask));
    int bars_since_entry=XDF_BarsSinceEntryM5(ps.opened_at);
    double mfe_r=XDF_MFER(ps,risk);
    XDFSetupFamily active_family=g_runtime_session.last_setup_family;
    string active_subtype=g_runtime_session.last_setup_subtype;
    if(active_subtype=="")
       active_subtype="UNKNOWN";
    bool guard_bars_ready=(bars_since_entry>=2);
    bool be_mfe_ready=(mfe_r>=(active_family==SETUP_MEAN_REVERSION?XDF_BE_MFE_MR_R:XDF_BE_MFE_ORB_R));
    bool trail_mfe_ready=(mfe_r>=XDF_TRAIL_MFE_R);
    bool be_moved_this_tick=false;
   if(!g_tp1_seen_for_position && risk>0.0 && move>=(risk*1.0))
     {
      g_tp1_seen_for_position=true;
      g_mgmt_state=g_pm.XDF_UpdateManagementState(ps,g_mgmt_state,true,g_be_moved_for_position,false,false);
      g_diag.Log("MGMT_PHASE","MGMT_TP1_ARMED");
     }

    if(!guard_bars_ready || !be_mfe_ready)
      {
       g_diag.Log("MGMT_GUARD",StringFormat("bars_since_entry=%d mfe_r=%.2f action=BE_DELAY reason=%s family=%d subtype=%s",
                                            bars_since_entry,mfe_r,(!guard_bars_ready?"need_2_closed_m5_bars":"insufficient_mfe_r"),(int)active_family,active_subtype));
      }
    if(guard_bars_ready && be_mfe_ready && g_pm.CanMoveToBreakeven(ps,bid,ask,1.0,g_specs.point,g_be_moved_for_position))
      {
       double be=ps.entry;
       string mod_diag;
      if(ps.direction>0 && ps.stop<be)
        {
         if(g_exec.ModifySLTP(g_symbol,ps.stop,NormalizeDouble(be,g_specs.digits),ps.take_profit,g_specs.point,mod_diag))
           {
             g_be_moved_for_position=true;
             g_mgmt_state=g_pm.XDF_UpdateManagementState(ps,g_mgmt_state,g_tp1_seen_for_position,true,false,false);
              g_diag.Log("MGMT_PHASE","MGMT_BE_DONE");
              g_diag.Log("MGMT_ACTION",StringFormat("bars_since_entry=%d mfe_r=%.2f action=BE reason=threshold_met family=%d subtype=%s",
                                                   bars_since_entry,mfe_r,(int)active_family,active_subtype));
             be_moved_this_tick=true;
             }
           g_diag.Log("BE_MOVE",mod_diag);
         }
      if(ps.direction<0 && ps.stop>be)
        {
         if(g_exec.ModifySLTP(g_symbol,ps.stop,NormalizeDouble(be,g_specs.digits),ps.take_profit,g_specs.point,mod_diag))
           {
             g_be_moved_for_position=true;
             g_mgmt_state=g_pm.XDF_UpdateManagementState(ps,g_mgmt_state,g_tp1_seen_for_position,true,false,false);
              g_diag.Log("MGMT_PHASE","MGMT_BE_DONE");
              g_diag.Log("MGMT_ACTION",StringFormat("bars_since_entry=%d mfe_r=%.2f action=BE reason=threshold_met family=%d subtype=%s",
                                                   bars_since_entry,mfe_r,(int)active_family,active_subtype));
             be_moved_this_tick=true;
             }
           g_diag.Log("BE_MOVE",mod_diag);
         }
      }

   if(g_pm.ShouldTimeExit(ps,InpMaxHoldMinutes))
     {
      CTrade t;
      g_mgmt_state=g_pm.XDF_UpdateManagementState(ps,g_mgmt_state,g_tp1_seen_for_position,g_be_moved_for_position,false,true);
      g_diag.Log("EXIT_TIMEOUT","Closed due to max hold minutes");
      g_diag.Log("MGMT_PHASE","MGMT_TIME_EXIT");
      if(t.PositionClose(g_symbol))
        {
         g_mgmt_state=MGMT_COMPLETE;
         g_diag.Log("MGMT_PHASE","MGMT_COMPLETE");
        }
      return;
     }

    static datetime last_trail_bar=0;
    if(be_moved_this_tick)
      {
       g_diag.Log("MGMT_GUARD",StringFormat("bars_since_entry=%d mfe_r=%.2f action=TRAIL_DELAY reason=be_moved_this_tick family=%d subtype=%s",
                                            bars_since_entry,mfe_r,(int)active_family,active_subtype));
       return;
      }
     if(!XDF_NewBar(g_symbol,PERIOD_M5,last_trail_bar))
        return;

    if(!guard_bars_ready || !trail_mfe_ready)
      {
       g_diag.Log("MGMT_GUARD",StringFormat("bars_since_entry=%d mfe_r=%.2f action=TRAIL_DELAY reason=%s family=%d subtype=%s",
                                            bars_since_entry,mfe_r,(!guard_bars_ready?"entry_or_early_bar_guard":"insufficient_mfe_r"),(int)active_family,active_subtype));
       return;
      }

   if(atr<=0.0)
      return;

   double min_step=MathMax(g_specs.point*10.0,atr*0.1);
   double new_sl=ps.stop;
   if(!g_pm.CanAdvanceTrail(ps,bid,ask,atr,g_specs.point,min_step,new_sl))
      return;

   double old_norm=NormalizeDouble(ps.stop,g_specs.digits);
   double new_norm=NormalizeDouble(new_sl,g_specs.digits);
    if(MathAbs(new_norm-old_norm)>=g_specs.point*5.0)
      {
       string mod_diag;
       if(g_exec.ModifySLTP(g_symbol,ps.stop,new_norm,ps.take_profit,g_specs.point,mod_diag))
          g_mgmt_state=g_pm.XDF_UpdateManagementState(ps,g_mgmt_state,g_tp1_seen_for_position,g_be_moved_for_position,true,false);
       g_diag.Log("TRAIL_UPDATE",mod_diag);
       g_diag.Log("MGMT_ACTION",StringFormat("bars_since_entry=%d mfe_r=%.2f action=TRAIL reason=threshold_met family=%d subtype=%s",
                                            bars_since_entry,mfe_r,(int)active_family,active_subtype));
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
    XDF_InitRuntimeSessionState(g_runtime_session);
    g_last_blocker.code=BLOCKER_NONE;
    g_last_blocker.message="NONE";

    g_diag.Log("INIT",StringFormat("resolvedSymbol=%s configuredSymbol=%s digits=%d minLot=%.2f serverTime=%s",g_symbol,InpSymbol,g_specs.digits,g_specs.min_lot,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)));
    datetime day_anchor=XDF_DayAnchor(TimeCurrent());
    datetime lstart=day_anchor + InpLondonStartHour*3600 + InpLondonStartMinute*60;
    datetime lor_end=lstart + InpLondonORMinutes*60;
    datetime ltrade_end=lstart + InpLondonTradeMinutes*60;
    datetime nstart=day_anchor + InpNYStartHour*3600 + InpNYStartMinute*60;
    datetime nor_end=nstart + InpNYORMinutes*60;
    datetime ntrade_end=nstart + InpNYTradeMinutes*60;
    g_diag.Log("SESSIONS",StringFormat("London start=%s orEnd=%s tradeEnd=%s | NewYork start=%s orEnd=%s tradeEnd=%s",
                                       TimeToString(lstart,TIME_DATE|TIME_MINUTES),TimeToString(lor_end,TIME_DATE|TIME_MINUTES),TimeToString(ltrade_end,TIME_DATE|TIME_MINUTES),
                                       TimeToString(nstart,TIME_DATE|TIME_MINUTES),TimeToString(nor_end,TIME_DATE|TIME_MINUTES),TimeToString(ntrade_end,TIME_DATE|TIME_MINUTES)));
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
      g_last_blocker.code=BLOCKER_DAILY_LIMIT;
      g_last_blocker.message="daily loss cap";
     }

   if(InpEnableDailyProfitLock && g_risk.DailyProfitLockHit(AccountInfoDouble(ACCOUNT_EQUITY),InpDailyProfitLockR,InpRiskPct))
     {
      g_daily_blocked=true;
      g_last_blocker.code=BLOCKER_DAILY_LIMIT;
      g_last_blocker.message="daily profit lock";
     }

   XDFPositionState ps;
   bool has_pos=g_pm.Read(g_symbol,ps);

   double atr=g_indicators.ATR();
   if(has_pos)
      XDF_ManageOpenPosition(atr);

   XDF_RefreshSessionState(now);
   XDFSessionId current_session=g_runtime_session.current_session;

    if(current_session==SESSION_NONE)
      {
       g_last_blocker.code=BLOCKER_SESSION_CLOSED;
       g_last_blocker.message="session closed";
       XDF_UpdatePanel(g_symbol,TimeToString(now,TIME_DATE|TIME_SECONDS),current_session,false,g_or,0.0,g_last_regime,SETUP_NONE,SETUP_NONE,g_last_score,g_last_blocker.message,XDF_CurrentSpreadPoints(),"n/a",has_pos,XDF_DailyPLPct(),g_daily_blocked,(has_pos?"OPEN":"NONE"),XDF_MgmtStateToString(g_mgmt_state));
       return;
      }

    if(XDF_InNewsBlock(now))
      {
       g_last_blocker.code=BLOCKER_SESSION_CLOSED;
       g_last_blocker.message="news block window";
       XDF_UpdatePanel(g_symbol,TimeToString(now,TIME_DATE|TIME_SECONDS),current_session,false,g_or,0.0,g_last_regime,SETUP_NONE,SETUP_NONE,g_last_score,g_last_blocker.message,XDF_CurrentSpreadPoints(),"n/a",has_pos,XDF_DailyPLPct(),g_daily_blocked,(has_pos?"OPEN":"NONE"),XDF_MgmtStateToString(g_mgmt_state));
       return;
      }

    if(!g_session_state.or_complete)
      {
       g_last_blocker.code=BLOCKER_SESSION_CLOSED;
       g_last_blocker.message="building opening range";
       XDF_UpdatePanel(g_symbol,TimeToString(now,TIME_DATE|TIME_SECONDS),current_session,false,g_or,0.0,g_last_regime,SETUP_NONE,SETUP_NONE,g_last_score,g_last_blocker.message,XDF_CurrentSpreadPoints(),"n/a",has_pos,XDF_DailyPLPct(),g_daily_blocked,(has_pos?"OPEN":"NONE"),XDF_MgmtStateToString(g_mgmt_state));
       return;
      }

   XDFDecisionContext ctx;
   string ctx_diag;
    bool session_changed=(g_session_state.session_start!=g_last_session_start);
    if(!XDF_BuildDecisionContext(g_symbol,now,g_runtime_session,g_session_state,g_indicators,g_vwap,g_or_engine,g_specs,InpMaxSpreadPoints,InpMinATR,InpMaxVWAPDistancePoints,InpMinSetupScore,InpMixedModeScoreThreshold,InpConflictOverrideScoreThreshold,true,g_last_session_start,g_last_m1_vwap_bar,ctx,g_or,ctx_diag))
      {
       g_last_blocker.code=BLOCKER_SESSION_CLOSED;
       g_last_blocker.message="OR unavailable";
       return;
      }
    if(session_changed)
      {
       g_last_or_build_signature="";
       g_last_or_validate_signature="";
      }
    if(g_runtime_session.or_log_signature!="" && g_runtime_session.or_log_signature!=g_last_or_build_signature)
      {
       int sep=StringFind(ctx_diag," | OR_VALIDATE ");
       if(sep>=0)
         {
          string build_line=StringSubstr(ctx_diag,0,sep);
          string validate_line=StringSubstr(ctx_diag,sep+3);
          g_diag.Log("OR_BUILD",build_line);
          if(g_runtime_session.or_last_validation_signature!="" && g_runtime_session.or_last_validation_signature!=g_last_or_validate_signature)
            {
             g_diag.Log("OR_VALIDATE",validate_line);
             g_last_or_validate_signature=g_runtime_session.or_last_validation_signature;
            }
         }
       else
          g_diag.Log("OR_BUILD",ctx_diag);
       g_last_or_build_signature=g_runtime_session.or_log_signature;
      }
    if(session_changed)
       g_filter.ResetSession();

    if(!XDF_NewBar(g_symbol,PERIOD_M5,g_last_m5_bar))
      {
       string m15_summary="pending";
       XDF_UpdatePanel(g_symbol,TimeToString(now,TIME_DATE|TIME_SECONDS),current_session,g_or.valid,g_or,g_vwap.Value(),g_last_regime,g_last_eligible_family,g_last_selected_family,g_last_score,g_last_blocker.message,XDF_CurrentSpreadPoints(),m15_summary,has_pos,XDF_DailyPLPct(),g_daily_blocked,(has_pos?"OPEN":"NONE"),XDF_MgmtStateToString(g_mgmt_state));
       return;
      }

   g_counters.setups_seen++;
   double spread_pts=ctx.spread_points;
   string m15_summary=StringFormat("al=%d slope=%.4f str=%.3f atr=%.2f",ctx.m15.trend_alignment,ctx.m15.slope,ctx.m15.slope_strength,ctx.m15.atr);

   XDFDecision decision;
   bool decision_ok=g_decision.XDF_EvaluateDecision(g_filter,ctx,decision);
   g_last_regime=(int)decision.regime;
   g_last_eligible_family=(int)decision.eligible_family;
   g_last_selected_family=(int)decision.selected_family;
   g_last_score=decision.selected_score.total;
   g_last_blocker=decision.blocker;
   g_diag.Log("REGIME",StringFormat("regime=%s reason=%s bothSides=%s m15=%s",
                                    XDF_RegimeToString((int)decision.regime),decision.regime_reason,(g_session_state.touched_above && g_session_state.touched_below)?"Y":"N",m15_summary));
   if(!decision_ok)
      {
       g_counters.setups_rejected++;
      g_diag.Log("SETUP_REJECT",StringFormat("blocker=%s detail=%s family=%d subtype=%s regime=%s orbEligible=%s orbSubtype=%s orbScoreRaw=%d orbScoreFinal=%d mrEligible=%s mrSubtype=%s mrScoreRaw=%d mrScoreFinal=%d mrPenalty=%s mrExceptional=%s stopDistPts=%.1f targetDistPts=%.1f spreadPts=%.1f expectedSlipPts=%.1f selected=%d selection_reason=%s reject_reason=%s",
                                              XDF_BlockerToString(decision.blocker.code),decision.blocker.message,
                                             (int)decision.selected_family,decision.selected_signal.subtype,XDF_RegimeToString((int)decision.regime),
                                             (decision.orb_signal.valid?"Y":"N"),decision.orb_subtype,decision.orb_score_raw,decision.orb_score_final,
                                             (decision.mr_signal.valid?"Y":"N"),decision.mr_subtype,decision.mr_score_raw,decision.mr_score_final,
                                             (decision.mr_penalty_applied?"Y":"N"),(decision.mr_exceptional_allowed?"Y":"N"),
                                             decision.stop_dist_points,decision.target_dist_points,decision.spread_points,decision.expected_slip_points,
                                             (int)decision.selected_family,decision.selection_reason,decision.selected_reject_reason));
        XDF_UpdatePanel(g_symbol,TimeToString(now,TIME_DATE|TIME_SECONDS),current_session,g_or.valid,g_or,g_vwap.Value(),g_last_regime,g_last_eligible_family,g_last_selected_family,g_last_score,g_last_blocker.message,spread_pts,m15_summary,has_pos,XDF_DailyPLPct(),g_daily_blocked,(has_pos?"OPEN":"NONE"),XDF_MgmtStateToString(g_mgmt_state));
        return;
       }

   XDFSignal chosen=decision.selected_signal;
   XDFScoreBreakdown score=decision.selected_score;
    g_counters.setups_scored++;
    g_diag.Log("SCORE",StringFormat("range=%d context=%d trigger=%d exec=%d vwap=%d noise=%d total=%d family=%d",
                                    score.range_quality,score.context_quality,score.trigger_quality,score.execution_quality,
                                    score.vwap_quality,score.noise_penalty,score.total,(int)chosen.family));
    g_diag.Log("FAMILY_SELECT",StringFormat("eligible=%d selected=%d selection_reason=%s family=%d subtype=%s regime=%s orbSubtype=%s orbScoreRaw=%d orbScoreFinal=%d mrSubtype=%s mrScoreRaw=%d mrScoreFinal=%d mrPenalty=%s mrExceptional=%s or_width_secondary_allow=%s or_primary=%.1f or_secondary=%.1f or_penalty=%d stopDistPts=%.1f targetDistPts=%.1f spreadPts=%.1f expectedSlipPts=%.1f reject_reason=%s",
                                            (int)decision.eligible_family,(int)decision.selected_family,decision.selection_reason,
                                            (int)decision.selected_family,decision.selected_signal.subtype,XDF_RegimeToString((int)decision.regime),
                                            decision.orb_subtype,decision.orb_score_raw,decision.orb_score_final,
                                            decision.mr_subtype,decision.mr_score_raw,decision.mr_score_final,
                                            (decision.mr_penalty_applied?"Y":"N"),(decision.mr_exceptional_allowed?"Y":"N"),
                                            (decision.or_width_secondary_allow?"Y":"N"),decision.or_width_primary_limit,decision.or_width_secondary_limit,decision.or_width_score_penalty,
                                            decision.stop_dist_points,decision.target_dist_points,decision.spread_points,decision.expected_slip_points,
                                            decision.selected_reject_reason));

     if(g_daily_blocked)
      {
       g_last_blocker.code=BLOCKER_DAILY_LIMIT;
       g_last_blocker.message="daily risk lock active";
       XDF_UpdatePanel(g_symbol,TimeToString(now,TIME_DATE|TIME_SECONDS),current_session,g_or.valid,g_or,g_vwap.Value(),g_last_regime,g_last_eligible_family,g_last_selected_family,g_last_score,g_last_blocker.message,spread_pts,m15_summary,has_pos,XDF_DailyPLPct(),g_daily_blocked,(has_pos?"OPEN":"NONE"),XDF_MgmtStateToString(g_mgmt_state));
       return;
      }

    if(has_pos)
      {
       g_last_blocker.code=BLOCKER_EXISTING_POSITION;
       g_last_blocker.message="existing position open";
       XDF_UpdatePanel(g_symbol,TimeToString(now,TIME_DATE|TIME_SECONDS),current_session,g_or.valid,g_or,g_vwap.Value(),g_last_regime,g_last_eligible_family,g_last_selected_family,g_last_score,g_last_blocker.message,spread_pts,m15_summary,has_pos,XDF_DailyPLPct(),g_daily_blocked,(has_pos?"OPEN":"NONE"),XDF_MgmtStateToString(g_mgmt_state));
       return;
      }

    if(g_trades_today>=InpMaxTradesPerDay || XDF_TradesInActiveSession()>=InpMaxTradesPerSession)
      {
       g_last_blocker.code=BLOCKER_SESSION_LIMIT;
       g_last_blocker.message="trade count limit";
       XDF_UpdatePanel(g_symbol,TimeToString(now,TIME_DATE|TIME_SECONDS),current_session,g_or.valid,g_or,g_vwap.Value(),g_last_regime,g_last_eligible_family,g_last_selected_family,g_last_score,g_last_blocker.message,spread_pts,m15_summary,has_pos,XDF_DailyPLPct(),g_daily_blocked,(has_pos?"OPEN":"NONE"),XDF_MgmtStateToString(g_mgmt_state));
       return;
      }

   bool lot_blocked=false;
   double stop_dist=MathAbs(chosen.entry-chosen.stop);
    double lots=g_risk.CalculateLots(g_specs,InpRiskPct,stop_dist,InpAllowMinLotOverride,lot_blocked,InpSizeFromEquity);
    if(lot_blocked || lots<=0.0)
      {
       g_counters.blocked_risk++;
       g_last_blocker.code=BLOCKER_VOLUME;
       g_last_blocker.message="risk model lot blocked";
       XDF_UpdatePanel(g_symbol,TimeToString(now,TIME_DATE|TIME_SECONDS),current_session,g_or.valid,g_or,g_vwap.Value(),g_last_regime,g_last_eligible_family,g_last_selected_family,g_last_score,g_last_blocker.message,spread_pts,m15_summary,has_pos,XDF_DailyPLPct(),g_daily_blocked,(has_pos?"OPEN":"NONE"),XDF_MgmtStateToString(g_mgmt_state));
       return;
      }

   string exec_diag;
     bool ok=g_exec.Place(g_symbol,chosen,lots,spread_pts,InpMaxSpreadPoints,(current_session!=SESSION_NONE),has_pos,(int)decision.regime,score.total,exec_diag);
   g_diag.Log("ORDER_ATTEMPT",exec_diag);
   if(ok)
     {
      g_trades_today++;
      XDF_IncSessionTrades();
      g_counters.trades_placed++;
      g_counters.setups_accepted++;
      g_last_blocker.code=BLOCKER_NONE;
      g_last_blocker.message="trade placed";
       g_diag.Log("TRADE",StringFormat("%s score=%d lots=%.2f reason=%s",(chosen.direction>0?"BUY":"SELL"),score.total,lots,chosen.reason));
       g_runtime_session.last_setup_family=chosen.family;
       g_runtime_session.last_direction=chosen.direction;
       g_runtime_session.last_setup_subtype=chosen.subtype;
       g_mgmt_state=MGMT_OPEN;
      }
   else
     {
      g_last_blocker.code=BLOCKER_EXECUTION_PREFLIGHT;
      g_last_blocker.message="order placement failed";
      g_diag.Log("ORDER_FAIL","Order request failed");
     }

    XDF_UpdatePanel(g_symbol,TimeToString(now,TIME_DATE|TIME_SECONDS),current_session,g_or.valid,g_or,g_vwap.Value(),g_last_regime,g_last_eligible_family,g_last_selected_family,g_last_score,g_last_blocker.message,spread_pts,m15_summary,has_pos,XDF_DailyPLPct(),g_daily_blocked,(has_pos?"OPEN":"NONE"),XDF_MgmtStateToString(g_mgmt_state));
  }
