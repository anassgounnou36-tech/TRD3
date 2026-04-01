#property script_show_inputs
#property strict

#include <XAUDailyFlow/SymbolSpecs.mqh>
#include <XAUDailyFlow/TimeWindows.mqh>
#include <XAUDailyFlow/SessionState.mqh>
#include <XAUDailyFlow/IndicatorEngine.mqh>
#include <XAUDailyFlow/VWAPEngine.mqh>
#include <XAUDailyFlow/OpeningRangeEngine.mqh>
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
   double point=SymbolInfoDouble(sym,SYMBOL_POINT);

   XDFSessionRuntimeState runtime_state;
   XDF_InitRuntimeSessionState(runtime_state);
   datetime last_session_start=0;
   XDFVWAPEngine vwap;

   int atr_handle=iATR(sym,PERIOD_M5,14);
   int m15_fast_handle=iMA(sym,PERIOD_M15,20,0,MODE_EMA,PRICE_CLOSE);
   int m15_slow_handle=iMA(sym,PERIOD_M15,50,0,MODE_EMA,PRICE_CLOSE);
   int m15_atr_handle=iATR(sym,PERIOD_M15,14);
   if(atr_handle==INVALID_HANDLE || m15_fast_handle==INVALID_HANDLE || m15_slow_handle==INVALID_HANDLE || m15_atr_handle==INVALID_HANDLE)
     {
      Print("Bar audit failed to init historical indicator handles");
      return;
     }

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
        }
      vwap.UpdateTo(ts);

      XDFOpeningRange or_data;
      string or_diag;
      bool have_or=or_engine.XDF_BuildExactOpeningRange(ss.session_start,ss.or_end,or_data,or_diag);
      if(have_or)
         Print(or_diag);
      if(!have_or || !runtime_state.or_complete)
        {
         Print(StringFormat("[%s] blocker=%s detail=%s",TimeToString(ts,TIME_DATE|TIME_MINUTES),XDF_BlockerToString(BLOCKER_SESSION_CLOSED),(!runtime_state.or_complete?"building opening range":"or unavailable")));
         continue;
        }

      int m5_shift=iBarShift(sym,PERIOD_M5,ts,false);
      int m15_shift=iBarShift(sym,PERIOD_M15,ts,false);
      if(m5_shift<2 || m15_shift<3)
         continue;

      MqlRates m5[3];
      ArraySetAsSeries(m5,true);
      if(CopyRates(sym,PERIOD_M5,m5_shift,3,m5)<3)
         continue;
      XDF_UpdateSessionTouches(runtime_state,m5[1].high,m5[1].low,or_data);
      ss.touched_above=runtime_state.touched_above;
      ss.touched_below=runtime_state.touched_below;

      double atr_buf[];
      ArraySetAsSeries(atr_buf,true);
      if(CopyBuffer(atr_handle,0,m5_shift+1,1,atr_buf)!=1)
         continue;
      double atr=atr_buf[0];
      double m15_fast[];
      double m15_slow[];
      double m15_atr[];
      ArraySetAsSeries(m15_fast,true);
      ArraySetAsSeries(m15_slow,true);
      ArraySetAsSeries(m15_atr,true);
      if(CopyBuffer(m15_fast_handle,0,m15_shift+1,3,m15_fast)!=3) continue;
      if(CopyBuffer(m15_slow_handle,0,m15_shift+1,1,m15_slow)!=1) continue;
      if(CopyBuffer(m15_atr_handle,0,m15_shift+1,1,m15_atr)!=1) continue;
      double slope=(m15_fast[0]-m15_fast[2]);

      double spread_pts=(point>0.0 ? ((rates[i].high-rates[i].low)/point*0.10) : 0.0);
      double mid=rates[i].close;

      XDFM15Context m15;
      ZeroMemory(m15);
      m15.fast_ema=m15_fast[0];
      m15.slow_ema=m15_slow[0];
      m15.slope=slope;
      m15.atr=m15_atr[0];
      m15.trend_long=(m15.fast_ema>=m15.slow_ema);
      m15.trend_short=(m15.fast_ema<=m15.slow_ema);
      m15.trend_alignment=(m15.trend_long && !m15.trend_short ? 1 : (m15.trend_short && !m15.trend_long ? -1 : 0));
      m15.slope_strength=(m15.atr>0.0 ? MathAbs(m15.slope)/m15.atr : 0.0);
      m15.price_vs_fast=(mid-m15.fast_ema);

      XDFDecisionContext ctx;
      ZeroMemory(ctx);
      ctx.symbol=sym;
      ctx.or_data=or_data;
      ctx.session=ss;
      ctx.m15=m15;
      ctx.vwap=vwap.Value();
      ctx.mid_price=mid;
      ctx.atr_m5=atr;
      ctx.spread_points=spread_pts;
      ctx.max_spread_points=InpMaxSpreadPoints;
      ctx.min_atr=InpMinATR;
      ctx.max_vwap_distance_points=InpMaxVWAPDistancePoints;
      ctx.point=point;
      ctx.allow_trade=true;

      XDFDecision dec;
      bool ok=decision_engine.XDF_EvaluateDecision(filter,ctx,dec);
      Print(StringFormat("[%s] ORW=%.2f VWAP=%.2f Regime=%s(%s) Eligible=%d Selected=%d Score=%d Blocker=%s detail=%s allow=%s",
                         TimeToString(ts,TIME_DATE|TIME_MINUTES),or_data.width,vwap.Value(),XDF_RegimeToString((int)dec.regime),dec.regime_reason,
                         (int)dec.eligible_family,(int)dec.selected_family,dec.selected_score.total,
                         XDF_BlockerToString(dec.blocker.code),dec.blocker.message,(ok?"Y":"N")));
     }

   IndicatorRelease(atr_handle);
   IndicatorRelease(m15_fast_handle);
   IndicatorRelease(m15_slow_handle);
   IndicatorRelease(m15_atr_handle);
  }
