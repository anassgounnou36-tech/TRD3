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

#define XDF_BUILD_TAG "v2.0.1-clean-trend-orb-restoration-1"

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
int g_accepted_orb_count=0;
int g_accepted_mr_count=0;
int g_accepted_orb_direct_break=0;
int g_accepted_orb_break_pause_continue=0;
int g_accepted_orb_break_retest_hold=0;
int g_accepted_orb_two_bar_confirm=0;
int g_accepted_mr_by_subtype=0;
double g_accepted_orb_net_rr_sum=0.0;
double g_accepted_mr_net_rr_sum=0.0;
double g_accepted_orb_direct_break_net_rr_sum=0.0;
double g_accepted_orb_break_pause_continue_net_rr_sum=0.0;
double g_accepted_orb_break_retest_hold_net_rr_sum=0.0;
double g_accepted_orb_two_bar_confirm_net_rr_sum=0.0;
int g_geometry_invalidated_candidates=0;
int g_rejected_by_regime_count=0;
int g_rejected_by_geometry_count=0;
int g_rejected_by_presend_payoff_count=0;
int g_rejected_by_postbreak_quality_count=0;
int g_orb_blocked_in_mr_count=0;
int g_mr_blocked_in_trend_count=0;
int g_orb_direct_break_blocked_both_sides_count=0;
int g_orb_direct_break_blocked_no_close_confirm_count=0;
int g_orb_direct_break_blocked_low_buffer_count=0;
int g_orb_direct_break_blocked_wide_stop_count=0;
int g_orb_direct_break_blocked_late_fragility_count=0;
int g_orb_direct_break_blocked_in_mixed_count=0;
int g_orb_pause_continue_blocked_mixed_weak_hold_count=0;
int g_orb_postbreak_reentered_or_too_deep_count=0;
int g_orb_postbreak_wicky_confirm_count=0;
int g_orb_postbreak_both_sides_violated_count=0;
int g_orb_postbreak_close_buffer_too_small_count=0;
int g_orb_postbreak_late_fragility_count=0;
int g_orb_postbreak_retest_no_acceptance_count=0;
int g_orb_postbreak_retest_unstable_continuation_count=0;
int g_orb_pause_continue_too_late_count=0;
int g_orb_pause_continue_late_quality_too_weak_count=0;
int g_orb_pause_continue_no_clean_hold_count=0;
int g_orb_two_bar_confirm_both_sides_violated_count=0;
int g_orb_two_bar_confirm_weak_second_close_count=0;
int g_orb_two_bar_confirm_too_late_count=0;
int g_orb_two_bar_confirm_dirty_sequence_count=0;
int g_orb_retest_hold_both_sides_dirty_count=0;
int g_orb_retest_hold_no_acceptance_count=0;
int g_orb_retest_hold_reentered_too_deep_count=0;
int g_orb_retest_hold_too_late_count=0;
int g_rejected_orb_no_subtype_match=0;
int g_rejected_orb_direct_break=0;
int g_rejected_orb_break_pause_continue=0;
int g_rejected_orb_break_retest_hold=0;
int g_rejected_orb_two_bar_confirm=0;
int g_reason_too_late_count=0;
int g_reason_both_sides_violated_count=0;
int g_reason_weak_second_close_count=0;
int g_reason_dirty_sequence_count=0;
int g_reason_no_clean_hold_count=0;
int g_reason_reentered_too_deep_count=0;
int g_reason_no_acceptance_count=0;
int g_reason_low_buffer_count=0;
int g_reason_geometry_fail_count=0;
int g_reason_regime_fail_count=0;
string g_last_guard_action="";
string g_last_guard_reason="";
datetime g_last_guard_bar=0;
XDFSetupFamily g_last_guard_family=SETUP_NONE;
string g_last_guard_subtype="";
const double XDF_BE_MFE_ORB_R=1.0;
const double XDF_BE_MFE_MR_R=1.3;
const double XDF_TRAIL_MFE_ORB_R=1.2;
const double XDF_TRAIL_MFE_MR_R=1.5;

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

bool XDF_IsGeometryInvalidReason(const string reason)
  {
   return(StringFind(reason,"GEOMETRY")>=0 ||
          StringFind(reason,"geometry")>=0 ||
          StringFind(reason,"stop_cap_fail")>=0 ||
          StringFind(reason,"rr_fail")>=0 ||
          StringFind(reason,"target_le_stop")>=0);
  }

void XDF_TrackORBDirectBreakVeto(const string reason)
  {
   if(reason=="ORB_DIRECT_BREAK_BOTH_SIDES_VIOLATED" || reason=="orb_direct_break_blocked_both_sides")
      g_orb_direct_break_blocked_both_sides_count++;
   else if(reason=="ORB_DIRECT_BREAK_NO_CLOSE_CONFIRM" || reason=="orb_direct_break_blocked_no_close_confirm")
      g_orb_direct_break_blocked_no_close_confirm_count++;
   else if(reason=="ORB_DIRECT_BREAK_LOW_BUFFER" || reason=="orb_direct_break_blocked_low_buffer")
      g_orb_direct_break_blocked_low_buffer_count++;
   else if(reason=="ORB_DIRECT_BREAK_WIDE_INVALIDATION" || reason=="orb_direct_break_blocked_wide_stop")
      g_orb_direct_break_blocked_wide_stop_count++;
   else if(reason=="ORB_DIRECT_BREAK_LATE_ENTRY" || reason=="orb_direct_break_blocked_late_fragility")
      g_orb_direct_break_blocked_late_fragility_count++;
   else if(reason=="ORB_POSTBREAK_DIRECT_BREAK_BLOCKED_IN_MIXED")
      g_orb_direct_break_blocked_in_mixed_count++;
   else if(reason=="ORB_POSTBREAK_PAUSE_REENTERED_OR_TOO_DEEP")
     {
      g_orb_pause_continue_blocked_mixed_weak_hold_count++;
      g_orb_postbreak_reentered_or_too_deep_count++;
     }
    else if(reason=="ORB_POSTBREAK_WICKY_CONFIRM")
       g_orb_postbreak_wicky_confirm_count++;
    else if(reason=="ORB_POSTBREAK_BOTH_SIDES_VIOLATED")
       g_orb_postbreak_both_sides_violated_count++;
    else if(reason=="ORB_POSTBREAK_CLOSE_BUFFER_TOO_SMALL")
       g_orb_postbreak_close_buffer_too_small_count++;
    else if(reason=="ORB_POSTBREAK_LATE_FRAGILITY")
       g_orb_postbreak_late_fragility_count++;
    else if(reason=="ORB_POSTBREAK_RETEST_NO_ACCEPTANCE")
       g_orb_postbreak_retest_no_acceptance_count++;
    else if(reason=="ORB_POSTBREAK_RETEST_UNSTABLE_CONTINUATION")
       g_orb_postbreak_retest_unstable_continuation_count++;
    else if(reason=="ORB_PAUSE_CONTINUE_TOO_LATE")
       g_orb_pause_continue_too_late_count++;
    else if(reason=="ORB_PAUSE_CONTINUE_LATE_QUALITY_TOO_WEAK")
       g_orb_pause_continue_late_quality_too_weak_count++;
    else if(reason=="ORB_PAUSE_CONTINUE_NO_CLEAN_HOLD")
       g_orb_pause_continue_no_clean_hold_count++;
    else if(reason=="ORB_TWO_BAR_CONFIRM_BOTH_SIDES_VIOLATED")
       g_orb_two_bar_confirm_both_sides_violated_count++;
    else if(reason=="ORB_TWO_BAR_CONFIRM_WEAK_SECOND_CLOSE")
       g_orb_two_bar_confirm_weak_second_close_count++;
    else if(reason=="ORB_TWO_BAR_CONFIRM_TOO_LATE")
       g_orb_two_bar_confirm_too_late_count++;
    else if(reason=="ORB_TWO_BAR_CONFIRM_DIRTY_SEQUENCE")
       g_orb_two_bar_confirm_dirty_sequence_count++;
    else if(reason=="ORB_RETEST_HOLD_BOTH_SIDES_DIRTY")
       g_orb_retest_hold_both_sides_dirty_count++;
    else if(reason=="ORB_RETEST_HOLD_NO_ACCEPTANCE")
       g_orb_retest_hold_no_acceptance_count++;
    else if(reason=="ORB_RETEST_HOLD_REENTERED_TOO_DEEP")
       g_orb_retest_hold_reentered_too_deep_count++;
    else if(reason=="ORB_RETEST_HOLD_TOO_LATE")
       g_orb_retest_hold_too_late_count++;
    else
       return;
    g_diag.Log("ORB_DIRECT_BREAK_VETO",reason);
  }

void XDF_TrackAcceptedSubtype(const XDFSignal &s)
  {
   if(s.family==SETUP_ORB_CONTINUATION)
     {
      if(s.subtype=="ORB_DIRECT_BREAK")
        {
         g_accepted_orb_direct_break++;
         g_accepted_orb_direct_break_net_rr_sum+=s.net_rr;
        }
      else if(s.subtype=="ORB_BREAK_PAUSE_CONTINUE")
        {
         g_accepted_orb_break_pause_continue++;
         g_accepted_orb_break_pause_continue_net_rr_sum+=s.net_rr;
        }
      else if(s.subtype=="ORB_BREAK_RETEST_HOLD")
        {
         g_accepted_orb_break_retest_hold++;
         g_accepted_orb_break_retest_hold_net_rr_sum+=s.net_rr;
        }
      else if(s.subtype=="ORB_TWO_BAR_CONFIRM")
        {
         g_accepted_orb_two_bar_confirm++;
         g_accepted_orb_two_bar_confirm_net_rr_sum+=s.net_rr;
        }
     }
   else if(s.family==SETUP_MEAN_REVERSION && s.subtype!="" && s.subtype!="NONE")
      g_accepted_mr_by_subtype++;
  }

void XDF_TrackRejectReasonBuckets(const string reason)
  {
   string r=reason;
   StringToLower(r);
   if(r=="")
      return;
   if(StringFind(r,"too_late")>=0)
      g_reason_too_late_count++;
   if(StringFind(r,"both_sides_violated")>=0)
      g_reason_both_sides_violated_count++;
   if(StringFind(r,"weak_second_close")>=0)
      g_reason_weak_second_close_count++;
   if(StringFind(r,"dirty_sequence")>=0)
      g_reason_dirty_sequence_count++;
   if(StringFind(r,"no_clean_hold")>=0)
      g_reason_no_clean_hold_count++;
   if(StringFind(r,"reentered_too_deep")>=0 || StringFind(r,"reentered_or_too_deep")>=0)
      g_reason_reentered_too_deep_count++;
   if(StringFind(r,"no_acceptance")>=0)
      g_reason_no_acceptance_count++;
   if(StringFind(r,"low_buffer")>=0 || StringFind(r,"close_buffer_too_small")>=0)
      g_reason_low_buffer_count++;
   if(StringFind(r,"geometry")>=0 || StringFind(r,"rr_fail")>=0 || StringFind(r,"stop_cap_fail")>=0)
      g_reason_geometry_fail_count++;
   if(StringFind(r,"regime")>=0 || StringFind(r,"blocked")>=0)
      g_reason_regime_fail_count++;
  }

void XDF_TrackFinalORBReject(const XDFDecision &decision)
  {
   string subtype=decision.last_orb_reject_subtype;
   string stage=decision.last_orb_reject_stage;
   string reason=decision.last_orb_reject_reason;
   if(reason=="")
      reason=decision.selected_reject_reason;
   if(reason=="")
      reason=decision.blocker.message;
   if(stage=="NO_SUBTYPE_FORMED" || subtype=="" || subtype=="NO_SUBTYPE" || subtype=="NONE")
      g_rejected_orb_no_subtype_match++;
   else if(subtype=="ORB_DIRECT_BREAK")
      g_rejected_orb_direct_break++;
   else if(subtype=="ORB_BREAK_PAUSE_CONTINUE")
      g_rejected_orb_break_pause_continue++;
   else if(subtype=="ORB_BREAK_RETEST_HOLD")
      g_rejected_orb_break_retest_hold++;
   else if(subtype=="ORB_TWO_BAR_CONFIRM")
      g_rejected_orb_two_bar_confirm++;
   XDF_TrackRejectReasonBuckets(reason);
  }

void XDF_LogMgmtGuard(const string action,const string reason,const int bars_since_entry,const double mfe_r,const XDFSetupFamily family,const string subtype,const datetime guard_bar)
  {
   bool should_log=(action!=g_last_guard_action ||
                    reason!=g_last_guard_reason ||
                    guard_bar!=g_last_guard_bar ||
                    family!=g_last_guard_family ||
                    subtype!=g_last_guard_subtype);
   if(!should_log)
      return;
   g_last_guard_action=action;
   g_last_guard_reason=reason;
   g_last_guard_bar=guard_bar;
   g_last_guard_family=family;
   g_last_guard_subtype=subtype;
   g_diag.Log("MGMT_GUARD",StringFormat("bars_since_entry=%d mfe_r=%.2f action=%s reason=%s family=%d subtype=%s",
                                        bars_since_entry,mfe_r,action,reason,(int)family,subtype));
  }

void XDF_ManageOpenPosition(double atr)
  {
   static string s_last_be_guard="";
   static string s_last_trail_guard="";
    XDFPositionState ps;
   if(!g_pm.Read(g_symbol,ps))
      return;

   if(g_last_position_opened!=ps.opened_at)
     {
      g_last_position_opened=ps.opened_at;
      g_be_moved_for_position=false;
      g_tp1_seen_for_position=false;
      g_mgmt_state=MGMT_OPEN;
      s_last_be_guard="";
      s_last_trail_guard="";
       g_last_guard_action="";
       g_last_guard_reason="";
       g_last_guard_bar=0;
       g_last_guard_family=SETUP_NONE;
       g_last_guard_subtype="";
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
     bool trail_mfe_ready=(mfe_r>=(active_family==SETUP_MEAN_REVERSION?XDF_TRAIL_MFE_MR_R:XDF_TRAIL_MFE_ORB_R));
     bool be_moved_this_tick=false;
    datetime guard_bar=iTime(g_symbol,PERIOD_M5,0);
   if(!g_tp1_seen_for_position && risk>0.0 && move>=(risk*1.0))
     {
      g_tp1_seen_for_position=true;
      g_mgmt_state=g_pm.XDF_UpdateManagementState(ps,g_mgmt_state,true,g_be_moved_for_position,false,false);
      g_diag.Log("MGMT_PHASE","MGMT_TP1_ARMED");
     }

     if(!guard_bars_ready || !be_mfe_ready)
       {
         string be_guard_reason=(!guard_bars_ready?"need_2_closed_m5_bars":"insufficient_mfe_r");
         if(be_guard_reason!=s_last_be_guard)
           {
            s_last_be_guard=be_guard_reason;
            XDF_LogMgmtGuard("BE_DELAY",be_guard_reason,bars_since_entry,mfe_r,active_family,active_subtype,guard_bar);
           }
        }
     else if(s_last_be_guard!="")
       {
        s_last_be_guard="";
        g_diag.Log("MGMT_ARM",StringFormat("bars_since_entry=%d mfe_r=%.2f action=BE_ARMED family=%d subtype=%s",
                                           bars_since_entry,mfe_r,(int)active_family,active_subtype));
       }
     if(guard_bars_ready && be_mfe_ready && g_pm.CanMoveToBreakeven(ps,bid,ask,1.0,g_specs.point,g_be_moved_for_position))
       {
       double be=ps.entry;
       string mod_diag;
       if(ps.direction>0 && ps.stop<be)
         {
          double old_sl_buy=NormalizeDouble(ps.stop,g_specs.digits);
          double new_sl_buy=NormalizeDouble(be,g_specs.digits);
          if(g_exec.ModifySLTP(g_symbol,ps.stop,NormalizeDouble(be,g_specs.digits),ps.take_profit,g_specs.point,mod_diag))
            {
              g_be_moved_for_position=true;
              g_mgmt_state=g_pm.XDF_UpdateManagementState(ps,g_mgmt_state,g_tp1_seen_for_position,true,false,false);
               g_diag.Log("MGMT_PHASE","MGMT_BE_DONE");
               g_diag.Log("MGMT_ACTION",StringFormat("bars_since_entry=%d mfe_r=%.2f action=BE family=%d subtype=%s oldSL=%.2f newSL=%.2f reason=threshold_met",
                                                    bars_since_entry,mfe_r,(int)active_family,active_subtype,old_sl_buy,new_sl_buy));
              be_moved_this_tick=true;
              }
            g_diag.Log("BE_MOVE",mod_diag);
          }
       if(ps.direction<0 && ps.stop>be)
         {
          double old_sl_sell=NormalizeDouble(ps.stop,g_specs.digits);
          double new_sl_sell=NormalizeDouble(be,g_specs.digits);
          if(g_exec.ModifySLTP(g_symbol,ps.stop,NormalizeDouble(be,g_specs.digits),ps.take_profit,g_specs.point,mod_diag))
            {
              g_be_moved_for_position=true;
              g_mgmt_state=g_pm.XDF_UpdateManagementState(ps,g_mgmt_state,g_tp1_seen_for_position,true,false,false);
               g_diag.Log("MGMT_PHASE","MGMT_BE_DONE");
               g_diag.Log("MGMT_ACTION",StringFormat("bars_since_entry=%d mfe_r=%.2f action=BE family=%d subtype=%s oldSL=%.2f newSL=%.2f reason=threshold_met",
                                                    bars_since_entry,mfe_r,(int)active_family,active_subtype,old_sl_sell,new_sl_sell));
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
        s_last_trail_guard="be_moved_this_tick";
        return;
       }
      if(!XDF_NewBar(g_symbol,PERIOD_M5,last_trail_bar))
         return;

     if(!guard_bars_ready || !trail_mfe_ready)
       {
        string trail_guard_reason=(!guard_bars_ready?"need_2_closed_m5_bars":"insufficient_mfe_r");
         if(trail_guard_reason!=s_last_trail_guard)
           {
            s_last_trail_guard=trail_guard_reason;
            XDF_LogMgmtGuard("TRAIL_DELAY",trail_guard_reason,bars_since_entry,mfe_r,active_family,active_subtype,last_trail_bar);
           }
         return;
        }
     if(s_last_trail_guard!="")
       {
        s_last_trail_guard="";
        g_diag.Log("MGMT_ARM",StringFormat("bars_since_entry=%d mfe_r=%.2f action=TRAIL_ARMED family=%d subtype=%s",
                                           bars_since_entry,mfe_r,(int)active_family,active_subtype));
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
       double old_sl=NormalizeDouble(ps.stop,g_specs.digits);
       double new_logged_sl=new_norm;
        if(g_exec.ModifySLTP(g_symbol,ps.stop,new_norm,ps.take_profit,g_specs.point,mod_diag))
           g_mgmt_state=g_pm.XDF_UpdateManagementState(ps,g_mgmt_state,g_tp1_seen_for_position,g_be_moved_for_position,true,false);
        g_diag.Log("TRAIL_UPDATE",mod_diag);
        g_diag.Log("MGMT_ACTION",StringFormat("bars_since_entry=%d mfe_r=%.2f action=TRAIL family=%d subtype=%s oldSL=%.2f newSL=%.2f reason=threshold_met",
                                             bars_since_entry,mfe_r,(int)active_family,active_subtype,old_sl,new_logged_sl));
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

     g_diag.Log("INIT",StringFormat("build=%s slipModel=min2_pct15_cap8 sourceGeom=enabled decisionGeom=enabled presendGeom=enabled symbol=%s digits=%d minLot=%.2f serverTime=%s",XDF_BUILD_TAG,g_symbol,g_specs.digits,g_specs.min_lot,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)));
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
   double avg_orb_net_rr=(g_accepted_orb_count>0?g_accepted_orb_net_rr_sum/g_accepted_orb_count:0.0);
   double avg_mr_net_rr=(g_accepted_mr_count>0?g_accepted_mr_net_rr_sum/g_accepted_mr_count:0.0);
   double avg_orb_direct_break_rr=(g_accepted_orb_direct_break>0?g_accepted_orb_direct_break_net_rr_sum/g_accepted_orb_direct_break:0.0);
   double avg_orb_pause_rr=(g_accepted_orb_break_pause_continue>0?g_accepted_orb_break_pause_continue_net_rr_sum/g_accepted_orb_break_pause_continue:0.0);
   double avg_orb_retest_rr=(g_accepted_orb_break_retest_hold>0?g_accepted_orb_break_retest_hold_net_rr_sum/g_accepted_orb_break_retest_hold:0.0);
   double avg_orb_two_bar_rr=(g_accepted_orb_two_bar_confirm>0?g_accepted_orb_two_bar_confirm_net_rr_sum/g_accepted_orb_two_bar_confirm:0.0);
   g_diag.Log("DEINIT_SUMMARY",StringFormat("build=%s accepted_orb=%d accepted_mr=%d accepted_orb_direct_break=%d accepted_orb_break_pause_continue=%d accepted_orb_break_retest_hold=%d accepted_orb_two_bar_confirm=%d accepted_mr_by_subtype=%d rejected_orb_no_subtype_match=%d rejected_orb_direct_break=%d rejected_orb_break_pause_continue=%d rejected_orb_break_retest_hold=%d rejected_orb_two_bar_confirm=%d reason_too_late=%d reason_both_sides_violated=%d reason_weak_second_close=%d reason_dirty_sequence=%d reason_no_clean_hold=%d reason_reentered_too_deep=%d reason_no_acceptance=%d reason_low_buffer=%d reason_geometry_fail=%d reason_regime_fail=%d orb_no_subtype_match=%d orb_rejected_by_postbreak_quality=%d orb_rejected_by_geometry=%d orb_rejected_by_regime=%d avg_accepted_orb_netRR=%.2f avg_accepted_mr_netRR=%.2f avg_orb_direct_break_netRR=%.2f avg_orb_break_pause_continue_netRR=%.2f avg_orb_break_retest_hold_netRR=%.2f avg_orb_two_bar_confirm_netRR=%.2f",
                                            XDF_BUILD_TAG,g_accepted_orb_count,g_accepted_mr_count,g_accepted_orb_direct_break,g_accepted_orb_break_pause_continue,g_accepted_orb_break_retest_hold,g_accepted_orb_two_bar_confirm,g_accepted_mr_by_subtype,g_rejected_orb_no_subtype_match,g_rejected_orb_direct_break,g_rejected_orb_break_pause_continue,g_rejected_orb_break_retest_hold,g_rejected_orb_two_bar_confirm,g_reason_too_late_count,g_reason_both_sides_violated_count,g_reason_weak_second_close_count,g_reason_dirty_sequence_count,g_reason_no_clean_hold_count,g_reason_reentered_too_deep_count,g_reason_no_acceptance_count,g_reason_low_buffer_count,g_reason_geometry_fail_count,g_reason_regime_fail_count,g_rejected_orb_no_subtype_match,g_rejected_by_postbreak_quality_count,g_rejected_by_geometry_count,g_rejected_by_regime_count,avg_orb_net_rr,avg_mr_net_rr,avg_orb_direct_break_rr,avg_orb_pause_rr,avg_orb_retest_rr,avg_orb_two_bar_rr));
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
     if(ctx.expected_slippage_points>XDF_EXPECTED_SLIPPAGE_CAP_POINTS)
       {
        // Defensive mismatch guard: should be impossible if ContextBuilder and runtime constants are in sync.
        g_last_blocker.code=BLOCKER_PAYOFF;
        g_last_blocker.message=StringFormat("BUILD_MISMATCH expected_slippage_points>%.1f",XDF_EXPECTED_SLIPPAGE_CAP_POINTS);
        g_diag.Log("BUILD_MISMATCH",StringFormat("build=%s expectedSlipPts=%.2f symbol=%s regime=%s",XDF_BUILD_TAG,ctx.expected_slippage_points,g_symbol,XDF_RegimeToString(g_last_regime)));
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
     XDF_TrackORBDirectBreakVeto(decision.orb_signal.reason_invalid);
     if(decision.orb_signal.postbreak_reject_reason!="" &&
        decision.orb_signal.postbreak_reject_reason!=decision.orb_signal.reason_invalid)
        XDF_TrackORBDirectBreakVeto(decision.orb_signal.postbreak_reject_reason);
    if(XDF_IsGeometryInvalidReason(decision.orb_signal.reason_invalid))
       g_geometry_invalidated_candidates++;
    if(XDF_IsGeometryInvalidReason(decision.mr_signal.reason_invalid))
       g_geometry_invalidated_candidates++;
    g_last_regime=(int)decision.regime;
   g_last_eligible_family=(int)decision.eligible_family;
    g_last_selected_family=(int)decision.selected_family;
    g_last_score=decision.selected_score.total;
    g_last_blocker=decision.blocker;
    if(decision.orb_block_reason=="MEAN_REVERSION_DEFAULT_BLOCK")
        g_orb_blocked_in_mr_count++;
    if(decision.mr_block_reason=="TREND_CONTINUATION_DEFAULT_BLOCK")
       g_mr_blocked_in_trend_count++;
    g_diag.Log("REGIME",StringFormat("regime=%s reason=%s bothSides=%s m15=%s",
                                     XDF_RegimeToString((int)decision.regime),decision.regime_reason,(g_session_state.touched_above && g_session_state.touched_below)?"Y":"N",m15_summary));
     if(!decision_ok)
        {
         bool orb_reject_counted=false;
         if(decision.orb_block_reason!="")
         {
            g_diag.Log("ORB_BLOCK",StringFormat("build=%s orb_block_reason=%s regime=%s subtype=%s",XDF_BUILD_TAG,decision.orb_block_reason,XDF_RegimeToString((int)decision.regime),decision.orb_subtype));
            g_rejected_by_regime_count++;
         }
        if(decision.orb_override_reason!="")
           g_diag.Log("ORB_OVERRIDE",StringFormat("build=%s orb_override_reason=%s regime=%s subtype=%s",XDF_BUILD_TAG,decision.orb_override_reason,XDF_RegimeToString((int)decision.regime),decision.orb_subtype));
        if(decision.blocker.code==BLOCKER_PAYOFF)
          {
           double rr=(decision.selected_signal.stop_points>0.0?decision.selected_signal.target_points/decision.selected_signal.stop_points:0.0);
           g_diag.Log("PAYOFF_FAIL",StringFormat("build=%s family=%d subtype=%s rr=%.2f stopPts=%.1f targetPts=%.1f spreadPts=%.1f slipPts=%.1f netRR=%.2f",
                                                  XDF_BUILD_TAG,(int)decision.selected_family,decision.selected_signal.subtype,rr,
                                                 decision.stop_dist_points,decision.target_dist_points,decision.spread_points,decision.expected_slip_points,decision.selected_signal.net_rr));
          }
         if(decision.blocker.code==BLOCKER_POSTBREAK_QUALITY &&
            decision.orb_subtype_formed &&
            decision.orb_postbreak_validator_entered &&
            decision.orb_rejected_by_postbreak &&
            decision.last_orb_reject_subtype!="" &&
            decision.last_orb_reject_subtype!="NONE" &&
            decision.last_orb_reject_subtype!="NO_SUBTYPE" &&
            decision.last_orb_reject_reason!="" &&
            decision.last_orb_reject_reason!="(null)")
           {
            g_rejected_by_postbreak_quality_count++;
            g_diag.Log("ORB_POSTBREAK_REJECT",StringFormat("| subtype=%s regime=%s reason=%s confirm_buffer_pts=%.2f bars_since_initial_break=%d",
                                                           decision.last_orb_reject_subtype,XDF_RegimeToString((int)decision.regime),decision.selected_reject_reason,
                                                           decision.selected_signal.confirm_buffer_pts,decision.selected_signal.bars_since_initial_break));
            XDF_TrackFinalORBReject(decision);
            orb_reject_counted=true;
           }
          if(decision.orb_reject_stage=="NO_SUBTYPE_FORMED")
            {
             g_diag.Log("ORB_NO_SUBTYPE",StringFormat("| regime=%s detail=no_orb_subtype_match",XDF_RegimeToString((int)decision.regime)));
             if(!orb_reject_counted)
               {
                XDF_TrackFinalORBReject(decision);
                orb_reject_counted=true;
               }
            }
        if(XDF_IsGeometryInvalidReason(decision.orb_signal.reason_invalid))
          {
            g_diag.Log("GEOMETRY_REJECT",StringFormat("build=%s family=%d subtype=%s reason_invalid=%s stopPts=%.1f targetPts=%.1f spreadPts=%.1f slipPts=%.1f netRR=%.2f",
                                                     XDF_BUILD_TAG,(int)decision.orb_signal.family,decision.orb_signal.subtype,decision.orb_signal.reason_invalid,
                                                     decision.orb_signal.stop_points,decision.orb_signal.target_points,decision.orb_signal.spread_points,decision.orb_signal.slip_points,decision.orb_signal.net_rr));
           g_rejected_by_geometry_count++;
          }
        if(XDF_IsGeometryInvalidReason(decision.mr_signal.reason_invalid))
          {
            g_diag.Log("GEOMETRY_REJECT",StringFormat("build=%s family=%d subtype=%s reason_invalid=%s stopPts=%.1f targetPts=%.1f spreadPts=%.1f slipPts=%.1f netRR=%.2f",
                                                     XDF_BUILD_TAG,(int)decision.mr_signal.family,decision.mr_signal.subtype,decision.mr_signal.reason_invalid,
                                                     decision.mr_signal.stop_points,decision.mr_signal.target_points,decision.mr_signal.spread_points,decision.mr_signal.slip_points,decision.mr_signal.net_rr));
           g_rejected_by_geometry_count++;
          }
        if(decision.mr_block_reason=="TREND_CONTINUATION_DEFAULT_BLOCK")
           g_rejected_by_regime_count++;
        if(decision.selected_reject_reason=="runtime_orb_blocked_in_mean_reversion")
           g_rejected_by_regime_count++;
        if(decision.selected_reject_reason=="final_selected_candidate_failed_geometry")
           g_rejected_by_geometry_count++;
        if(decision.primary_reject_reason!="")
           g_diag.Log("FAMILY_PRIMARY_REJECT",decision.primary_reject_reason);
        if(decision.fallback_attempted)
           g_diag.Log((decision.fallback_accepted?"FAMILY_FALLBACK_ACCEPT":"FAMILY_FALLBACK_REJECT"),decision.fallback_reason);
         if(!orb_reject_counted &&
            (decision.selected_family==SETUP_ORB_CONTINUATION || decision.last_orb_reject_stage!="" || decision.last_orb_reject_subtype!=""))
            XDF_TrackFinalORBReject(decision);
         g_counters.setups_rejected++;
      g_diag.Log("SETUP_REJECT",StringFormat("blocker=%s detail=%s family=%d subtype=%s regime=%s orbEligible=%s orbSubtype=%s orbSource=%s orbReasonInvalid=%s orbPostbreakReject=%s orbPostbreakPass=%s orbPostbreakScore=%.1f orbConfirmBufferPts=%.2f orbBarsSinceBreak=%d orbRejectSubtype=%s orbRejectReason=%s orbRejectStage=%s orbScoreRaw=%d orbScoreFinal=%d mrEligible=%s mrSubtype=%s mrSource=%s mrScoreRaw=%d mrScoreFinal=%d mrPenalty=%s mrExceptional=%s mrBlockReason=%s mrOverrideReason=%s orbBlockReason=%s orbOverrideReason=%s or_width_secondary_allow=%s or_primary=%.1f or_secondary=%.1f or_penalty=%d stopDistPts=%.1f targetDistPts=%.1f spreadPts=%.1f expectedSlipPts=%.1f selected=%d selection_reason=%s reject_reason=%s",
                                                XDF_BlockerToString(decision.blocker.code),decision.blocker.message,
                                                (int)decision.selected_family,decision.selected_signal.subtype,XDF_RegimeToString((int)decision.regime),
                                               (decision.orb_signal.valid?"Y":"N"),decision.orb_subtype,decision.orb_signal.reason,decision.orb_signal.reason_invalid,decision.orb_signal.postbreak_reject_reason,(decision.orb_signal.postbreak_quality_pass?"Y":"N"),decision.orb_signal.postbreak_quality_score,decision.orb_signal.confirm_buffer_pts,decision.orb_signal.bars_since_initial_break,
                                               decision.last_orb_reject_subtype,decision.last_orb_reject_reason,decision.last_orb_reject_stage,decision.orb_score_raw,decision.orb_score_final,
                                               (decision.mr_signal.valid?"Y":"N"),decision.mr_subtype,decision.mr_signal.reason,decision.mr_score_raw,decision.mr_score_final,
                                               (decision.mr_penalty_applied?"Y":"N"),(decision.mr_exceptional_allowed?"Y":"N"),
                                               decision.mr_block_reason,decision.mr_override_reason,decision.orb_block_reason,decision.orb_override_reason,
                                              (decision.or_width_secondary_allow?"Y":"N"),decision.or_width_primary_limit,decision.or_width_secondary_limit,decision.or_width_score_penalty,
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
    g_diag.Log("FAMILY_SELECT",StringFormat("eligible=%d selected=%d selection_reason=%s family=%d subtype=%s regime=%s orbSubtype=%s orbSource=%s orbPostbreakPass=%s orbPostbreakScore=%.1f orbConfirmBufferPts=%.2f orbBarsSinceBreak=%d orbScoreRaw=%d orbScoreFinal=%d mrSubtype=%s mrSource=%s mrScoreRaw=%d mrScoreFinal=%d mrPenalty=%s mrExceptional=%s mrBlockReason=%s mrOverrideReason=%s orbBlockReason=%s orbOverrideReason=%s or_width_secondary_allow=%s or_primary=%.1f or_secondary=%.1f or_penalty=%d stopDistPts=%.1f targetDistPts=%.1f spreadPts=%.1f expectedSlipPts=%.1f reject_reason=%s",
                                             (int)decision.eligible_family,(int)decision.selected_family,decision.selection_reason,
                                             (int)decision.selected_family,decision.selected_signal.subtype,XDF_RegimeToString((int)decision.regime),
                                             decision.orb_subtype,decision.orb_signal.reason,(decision.orb_signal.postbreak_quality_pass?"Y":"N"),decision.orb_signal.postbreak_quality_score,decision.orb_signal.confirm_buffer_pts,decision.orb_signal.bars_since_initial_break,decision.orb_score_raw,decision.orb_score_final,
                                             decision.mr_subtype,decision.mr_signal.reason,decision.mr_score_raw,decision.mr_score_final,
                                             (decision.mr_penalty_applied?"Y":"N"),(decision.mr_exceptional_allowed?"Y":"N"),
                                             decision.mr_block_reason,decision.mr_override_reason,decision.orb_block_reason,decision.orb_override_reason,
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

    if(decision.regime==REGIME_MEAN_REVERSION &&
       chosen.family==SETUP_ORB_CONTINUATION)
      {
       g_rejected_by_regime_count++;
       g_orb_blocked_in_mr_count++;
       g_diag.Log("RUNTIME_GUARD_FAIL","orb_in_mean_reversion_without_override");
       g_last_blocker.code=BLOCKER_REGIME;
       g_last_blocker.message="runtime_orb_blocked_in_mean_reversion";
       XDF_UpdatePanel(g_symbol,TimeToString(now,TIME_DATE|TIME_SECONDS),current_session,g_or.valid,g_or,g_vwap.Value(),g_last_regime,g_last_eligible_family,g_last_selected_family,g_last_score,g_last_blocker.message,spread_pts,m15_summary,has_pos,XDF_DailyPLPct(),g_daily_blocked,(has_pos?"OPEN":"NONE"),XDF_MgmtStateToString(g_mgmt_state));
       return;
      }

    string exec_diag;
    bool ok=g_exec.Place(g_symbol,chosen,lots,spread_pts,ctx.expected_slippage_points,InpMaxSpreadPoints,(current_session!=SESSION_NONE),has_pos,(int)decision.regime,score.total,exec_diag);
    g_diag.Log("ORDER_ATTEMPT",exec_diag);
    if(ok)
      {
      g_trades_today++;
      XDF_IncSessionTrades();
      g_counters.trades_placed++;
      g_counters.setups_accepted++;
      g_last_blocker.code=BLOCKER_NONE;
      g_last_blocker.message="trade placed";
        g_diag.Log("TRADE",StringFormat("build=%s regime=%s family=%d subtype=%s source=%s postbreak_quality_score=%.1f confirm_buffer_pts=%.2f bars_since_initial_break=%d score=%d stopPts=%.1f targetPts=%.1f spreadPts=%.1f slipPts=%.1f grossRR=%.2f netRR=%.2f selection_reason=%s side=%s lots=%.2f",
                                        XDF_BUILD_TAG,XDF_RegimeToString((int)decision.regime),(int)chosen.family,chosen.subtype,chosen.reason,
                                        chosen.postbreak_quality_score,chosen.confirm_buffer_pts,chosen.bars_since_initial_break,score.total,
                                        chosen.stop_points,chosen.target_points,chosen.spread_points,chosen.slip_points,chosen.gross_rr,chosen.net_rr,decision.selection_reason,
                                        (chosen.direction>0?"BUY":"SELL"),lots));
       g_runtime_session.last_setup_family=chosen.family;
       g_runtime_session.last_direction=chosen.direction;
        g_runtime_session.last_setup_subtype=chosen.subtype;
        g_mgmt_state=MGMT_OPEN;
         if(chosen.family==SETUP_ORB_CONTINUATION)
           {
            g_accepted_orb_count++;
            g_accepted_orb_net_rr_sum+=chosen.net_rr;
            chosen.orb_lifecycle=ORB_LIFE_SENT;
            XDF_TrackAcceptedSubtype(chosen);
           }
          else if(chosen.family==SETUP_MEAN_REVERSION)
           {
            g_accepted_mr_count++;
            g_accepted_mr_net_rr_sum+=chosen.net_rr;
            chosen.mr_lifecycle=MR_LIFE_SENT;
            XDF_TrackAcceptedSubtype(chosen);
           }
         }
    else
      {
       g_last_blocker.code=BLOCKER_EXECUTION_PREFLIGHT;
       g_last_blocker.message="order placement failed";
        if(XDF_IsGeometryInvalidReason(chosen.reason_invalid))
          {
          g_diag.Log("GEOMETRY_REJECT",StringFormat("build=%s family=%d subtype=%s reason_invalid=%s stopPts=%.1f targetPts=%.1f spreadPts=%.1f slipPts=%.1f netRR=%.2f",
                                                    XDF_BUILD_TAG,(int)chosen.family,chosen.subtype,chosen.reason_invalid,chosen.stop_points,chosen.target_points,chosen.spread_points,chosen.slip_points,chosen.net_rr));
           g_rejected_by_geometry_count++;
          }
       if(StringFind(exec_diag,"PRE_SEND_PAYOFF_FAIL")>=0)
          g_rejected_by_presend_payoff_count++;
        g_diag.Log("ORDER_FAIL","Order request failed");
      }

    XDF_UpdatePanel(g_symbol,TimeToString(now,TIME_DATE|TIME_SECONDS),current_session,g_or.valid,g_or,g_vwap.Value(),g_last_regime,g_last_eligible_family,g_last_selected_family,g_last_score,g_last_blocker.message,spread_pts,m15_summary,has_pos,XDF_DailyPLPct(),g_daily_blocked,(has_pos?"OPEN":"NONE"),XDF_MgmtStateToString(g_mgmt_state));
  }
