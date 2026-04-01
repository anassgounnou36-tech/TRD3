#property script_show_inputs
#property strict

#include <XAUDailyFlow/SymbolSpecs.mqh>
#include <XAUDailyFlow/TimeWindows.mqh>
#include <XAUDailyFlow/SessionState.mqh>
#include <XAUDailyFlow/IndicatorEngine.mqh>
#include <XAUDailyFlow/VWAPEngine.mqh>
#include <XAUDailyFlow/OpeningRangeEngine.mqh>
#include <XAUDailyFlow/ContextBuilder.mqh>
#include <XAUDailyFlow/NoTradeFilter.mqh>
#include <XAUDailyFlow/StrategyDecision.mqh>
#include <XAUDailyFlow/Journal.mqh>

input string InpSymbol = "";
input ENUM_TIMEFRAMES InpTF = PERIOD_M5;
input int InpBars = 50;
input bool InpUseDateRange = false;
input datetime InpStartDate = D'2026.01.01 00:00';
input datetime InpEndDate = D'2026.12.31 23:59';
input int InpSessionStartHour = 8;
input int InpSessionStartMinute = 0;
input int InpSessionORMinutes = 10;
input double InpMaxSpreadPoints = 55.0;
input double InpMinATR = 1.2;
input double InpMaxVWAPDistancePoints = 420.0;
input int InpMinSetupScore = 58;
input int InpMixedModeScoreThreshold = 63;
input int InpConflictOverrideScoreThreshold = 75;

void OnStart()
  {
   string sym=XDF_ResolveSymbol(InpSymbol);
   if(!SymbolSelect(sym,true))
     {
      Print("Bar audit failed to select symbol ",sym);
      return;
     }
   if(InpUseDateRange && InpEndDate<=InpStartDate)
     {
      Print("Bar audit invalid date range: end must be after start");
      return;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int copied=(InpUseDateRange?CopyRates(sym,InpTF,InpStartDate,InpEndDate,rates):CopyRates(sym,InpTF,0,InpBars,rates));
   if(copied<=0)
     {
      Print("Bar audit failed for symbol ",sym);
      return;
     }

   XDFSessionConfig cfg;
   cfg.start_hour=InpSessionStartHour;
   cfg.start_minute=InpSessionStartMinute;
   cfg.or_minutes=InpSessionORMinutes;
   cfg.trade_minutes=120;
   cfg.id=SESSION_LONDON;
   cfg.name="AuditSession";

   XDFNoTradeFilter filter;
   XDFStrategyDecisionEngine decision_engine;
   XDFOpeningRangeEngine or_engine;
   or_engine.Init(sym);
   XDFIndicatorEngine ind;
   if(!ind.Init(sym))
     {
      Print("Bar audit failed to init indicator engine");
      return;
     }
   XDFSymbolSpecs specs;
   if(!XDF_LoadSymbolSpecs(sym,specs))
     {
      Print("Bar audit failed to load symbol specs");
      return;
     }

   XDFSessionRuntimeState runtime_state;
   XDF_InitRuntimeSessionState(runtime_state);
   datetime last_session_start=0;
   datetime last_m1_vwap_bar=0;
   string last_or_log_signature="";
   string last_or_validation_signature="";
   XDFVWAPEngine vwap;

   Print("=== XAUDailyFlow Bar Audit (shared decision path) ===");
   Print("Symbol=",sym," TF=",EnumToString(InpTF)," Bars=",copied," Mode=",(InpUseDateRange?"DATE_RANGE":"BAR_COUNT"));

   for(int i=copied-1;i>=0;i--)
     {
      datetime ts=rates[i].time;
      XDFSessionState ss;
      XDF_BuildSessionState(cfg,ts,ss);
      runtime_state.current_session=cfg.id;
      runtime_state.day_anchor=ss.day_anchor;
      runtime_state.session_start=ss.session_start;
      runtime_state.or_end=ss.or_end;
      runtime_state.trade_end=ss.trade_end;
      runtime_state.or_complete=(ts>=ss.or_end);
      if(last_session_start!=ss.session_start)
        {
         filter.ResetSession();
         runtime_state.touched_above=false;
         runtime_state.touched_below=false;
         vwap.Reset(sym,ss.session_start);
         last_session_start=ss.session_start;
         last_or_log_signature="";
         last_or_validation_signature="";
        }
      XDFOpeningRange or_data;
      XDFDecisionContext ctx;
      string ctx_diag;
      bool have_ctx=XDF_BuildDecisionContext(sym,ts,runtime_state,ss,ind,vwap,or_engine,specs,InpMaxSpreadPoints,InpMinATR,InpMaxVWAPDistancePoints,InpMinSetupScore,InpMixedModeScoreThreshold,InpConflictOverrideScoreThreshold,false,last_session_start,last_m1_vwap_bar,ctx,or_data,ctx_diag);
      if(have_ctx && runtime_state.or_log_signature!="" && runtime_state.or_log_signature!=last_or_log_signature)
        {
         int sep=StringFind(ctx_diag," | OR_VALIDATE ");
         if(sep>=0)
           {
            Print(StringSubstr(ctx_diag,0,sep));
            if(runtime_state.or_last_validation_signature!="" && runtime_state.or_last_validation_signature!=last_or_validation_signature)
              {
               Print(StringSubstr(ctx_diag,sep+3));
               last_or_validation_signature=runtime_state.or_last_validation_signature;
              }
           }
         else
            Print(ctx_diag);
         last_or_log_signature=runtime_state.or_log_signature;
        }
      if(!have_ctx || !runtime_state.or_complete)
        {
          Print(StringFormat("[%s] blocker=%s detail=%s",TimeToString(ts,TIME_DATE|TIME_MINUTES),XDF_BlockerToString(BLOCKER_SESSION_CLOSED),(!runtime_state.or_complete?"building opening range":"or unavailable")));
          continue;
        }

      XDFDecision dec;
      bool ok=decision_engine.XDF_EvaluateDecision(filter,ctx,dec);
      Print(StringFormat("[%s] ORW=%.2f VWAP=%.2f Regime=%s(%s) eligible_state=%d Selected=%d Score=%d orb_valid=%s orb_subtype=%s orb_reason_invalid=%s orb_score=%d mr_valid=%s mr_subtype=%s mr_reason_invalid=%s mr_score=%d Blocker=%s detail=%s reject=%s allow=%s",
                         TimeToString(ts,TIME_DATE|TIME_MINUTES),or_data.width,vwap.Value(),XDF_RegimeToString((int)dec.regime),dec.regime_reason,
                          (int)dec.eligible_family,(int)dec.selected_family,dec.selected_score.total,
                          (dec.orb_signal.valid?"Y":"N"),dec.orb_subtype,dec.orb_signal.reason_invalid,dec.orb_score.total,
                          (dec.mr_signal.valid?"Y":"N"),dec.mr_subtype,dec.mr_signal.reason_invalid,dec.mr_score.total,
                          XDF_BlockerToString(dec.blocker.code),dec.blocker.message,dec.selected_reject_reason,(ok?"Y":"N")));
      }

   ind.Release();
  }
