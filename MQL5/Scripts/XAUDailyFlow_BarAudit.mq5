#property script_show_inputs
#property strict

#include <XAUDailyFlow/SymbolSpecs.mqh>
#include <XAUDailyFlow/TimeWindows.mqh>
#include <XAUDailyFlow/IndicatorEngine.mqh>
#include <XAUDailyFlow/VWAPEngine.mqh>
#include <XAUDailyFlow/OpeningRangeEngine.mqh>
#include <XAUDailyFlow/RegimeEngine.mqh>
#include <XAUDailyFlow/ORBSignal.mqh>
#include <XAUDailyFlow/MeanReversionSignal.mqh>
#include <XAUDailyFlow/SetupScorer.mqh>
#include <XAUDailyFlow/NoTradeFilter.mqh>
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

string ResolveSymbol(const string configured)
  {
   return(XDF_ResolveSymbol(configured));
  }

void OnStart()
  {
   string sym=ResolveSymbol(InpSymbol);
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
   int copied=0;
   if(InpUseDateRange)
      copied=CopyRates(sym,InpTF,InpStartDate,InpEndDate,rates);
   else
      copied=CopyRates(sym,InpTF,0,InpBars,rates);
   if(copied<=0)
     {
      Print("Bar audit failed for symbol ",sym);
      return;
     }

   Print("=== XAUDailyFlow Bar Audit ===");
   Print("Symbol=",sym," TF=",EnumToString(InpTF)," Bars=",copied," Mode=",(InpUseDateRange?"DATE_RANGE":"BAR_COUNT"));

   XDFSessionConfig cfg;
   cfg.start_hour=InpSessionStartHour;
   cfg.start_minute=InpSessionStartMinute;
   cfg.or_minutes=InpSessionORMinutes;
   cfg.trade_minutes=120;
   cfg.id=SESSION_LONDON;
   cfg.name="AuditSession";

   int atr_handle=iATR(sym,PERIOD_M5,14);
   int m15_fast_handle=iMA(sym,PERIOD_M15,20,0,MODE_EMA,PRICE_CLOSE);
   int m15_slow_handle=iMA(sym,PERIOD_M15,50,0,MODE_EMA,PRICE_CLOSE);
   if(atr_handle==INVALID_HANDLE || m15_fast_handle==INVALID_HANDLE || m15_slow_handle==INVALID_HANDLE)
     {
      Print("Bar audit failed to init historical indicator handles");
      return;
     }

   double spread_pts=0.0;
   double point=SymbolInfoDouble(sym,SYMBOL_POINT);
   XDFNoTradeFilter nf;
   for(int i=copied-1;i>=0;i--)
     {
      datetime ts=rates[i].time;
      XDFSessionState ss;
      XDF_BuildSessionState(cfg,ts,ss);
      XDFOpeningRangeEngine or_engine;
      or_engine.Init(sym);
      XDFOpeningRange or_data;
      bool have_or=or_engine.Build(ss.session_start,ss.or_end,or_data);
      bool or_complete=(ts>=ss.or_end);

      XDFVWAPEngine vwap;
      vwap.Reset(sym,ss.session_start);
      vwap.UpdateTo(ts);

      int m5_shift=iBarShift(sym,PERIOD_M5,ts,false);
      int m15_shift=iBarShift(sym,PERIOD_M15,ts,false);
      if(m5_shift<2 || m15_shift<3)
         continue;
      double atr_buf[];
      ArraySetAsSeries(atr_buf,true);
      if(CopyBuffer(atr_handle,0,m5_shift+1,1,atr_buf)!=1)
         continue;
      double atr=atr_buf[0];
      double m15_fast[];
      double m15_slow[];
      ArraySetAsSeries(m15_fast,true);
      ArraySetAsSeries(m15_slow,true);
      if(CopyBuffer(m15_fast_handle,0,m15_shift+1,3,m15_fast)!=3) continue;
      if(CopyBuffer(m15_slow_handle,0,m15_shift+1,1,m15_slow)!=1) continue;
      double m15s=(m15_fast[0]-m15_fast[2]);
      bool m15l=(m15_fast[0]>=m15_slow[0]);
      bool m15sh=(m15_fast[0]<=m15_slow[0]);
      double mid=rates[i].close;
      if(point>0.0)
         spread_pts=(rates[i].high-rates[i].low)/point*0.10;
      double vwap_dist=(point>0.0 ? MathAbs(mid-vwap.Value())/point : 0.0);
      double atr_points=(point>0.0 ? atr/point : 0.0);

      XDFRegimeEngine re;
      string regime_reason;
      XDFRegime regime=REGIME_NO_TRADE;
      if(or_complete && have_or)
         regime=re.Detect(or_data,atr,vwap.Value(),mid,false,m15s,m15l,m15sh,regime_reason);
      else
         regime_reason="or_building_or_unavailable";
      XDFSignal orb;
      XDFSignal mr;
      ZeroMemory(orb);
      ZeroMemory(mr);
      if(or_complete && have_or)
        {
         MqlRates sig_m5[];
         ArraySetAsSeries(sig_m5,true);
         if(CopyRates(sym,PERIOD_M5,m5_shift,5,sig_m5)>=5)
           {
            MqlRates b=sig_m5[1];
            double body=MathAbs(b.close-b.open);
            double range=b.high-b.low;
            bool strong=(range>0.0 && (body/range)>=0.45);
            bool ema_long_ok=m15l;
            bool ema_short_ok=m15sh;
            if(strong && b.close>or_data.high && b.close>vwap.Value() && ema_long_ok && (b.close-or_data.high)<(atr*1.5))
              {
               orb.family=SETUP_ORB_CONTINUATION;
               orb.valid=true; orb.direction=1; orb.reason="ORB long continuation";
               orb.entry=b.close; orb.stop=MathMin(or_data.low-atr*0.35,orb.entry-point*5.0);
               orb.tp_hint=orb.entry+atr*1.1; orb.stop_distance=MathAbs(orb.entry-orb.stop); orb.target_distance=MathAbs(orb.tp_hint-orb.entry);
               orb.trigger_body_ratio=(range>0.0 ? body/range : 0.0); orb.vwap_side_ok=true;
              }
            if(strong && b.close<or_data.low && b.close<vwap.Value() && ema_short_ok && (or_data.low-b.close)<(atr*1.5))
              {
               orb.family=SETUP_ORB_CONTINUATION;
               orb.valid=true; orb.direction=-1; orb.reason="ORB short continuation";
               orb.entry=b.close; orb.stop=MathMax(or_data.high+atr*0.35,orb.entry+point*5.0);
               orb.tp_hint=orb.entry-atr*1.1; orb.stop_distance=MathAbs(orb.entry-orb.stop); orb.target_distance=MathAbs(orb.tp_hint-orb.entry);
               orb.trigger_body_ratio=(range>0.0 ? body/range : 0.0); orb.vwap_side_ok=true;
              }

            MqlRates latest=sig_m5[1];
            MqlRates prev=sig_m5[2];
            double min_sweep=atr*0.20;
            double mr_body=MathAbs(latest.close-latest.open);
            if(prev.low<or_data.low-min_sweep && latest.close>or_data.low && latest.close<or_data.high && mr_body>=(latest.high-latest.low)*0.35)
              {
               mr.family=SETUP_MEAN_REVERSION;
               mr.valid=true; mr.direction=1; mr.reason="Failed OR downside reclaim";
               mr.entry=latest.close; mr.stop=prev.low-atr*0.20; mr.tp_hint=(vwap.Value()>mr.entry ? vwap.Value() : or_data.midpoint);
               if(mr.tp_hint<=mr.entry || mr.tp_hint==0.0) mr.tp_hint=mr.entry+atr*0.9;
               mr.stop_distance=MathAbs(mr.entry-mr.stop); mr.target_distance=MathAbs(mr.tp_hint-mr.entry);
               mr.trigger_body_ratio=((latest.high-latest.low)>0.0 ? mr_body/(latest.high-latest.low) : 0.0); mr.vwap_side_ok=(vwap.Value()>=mr.entry);
              }
            if(prev.high>or_data.high+min_sweep && latest.close<or_data.high && latest.close>or_data.low && mr_body>=(latest.high-latest.low)*0.35)
              {
               mr.family=SETUP_MEAN_REVERSION;
               mr.valid=true; mr.direction=-1; mr.reason="Failed OR upside reclaim";
               mr.entry=latest.close; mr.stop=prev.high+atr*0.20; mr.tp_hint=(vwap.Value()<mr.entry ? vwap.Value() : or_data.midpoint);
               if(mr.tp_hint>=mr.entry || mr.tp_hint==0.0) mr.tp_hint=mr.entry-atr*0.9;
               mr.stop_distance=MathAbs(mr.entry-mr.stop); mr.target_distance=MathAbs(mr.tp_hint-mr.entry);
               mr.trigger_body_ratio=((latest.high-latest.low)>0.0 ? mr_body/(latest.high-latest.low) : 0.0); mr.vwap_side_ok=(vwap.Value()<=mr.entry);
              }
           }
        }
      XDFSignal chosen=(orb.valid?orb:mr);
      XDFSetupScorer scorer;
      XDFScoreBreakdown sb=scorer.Score(chosen,or_data,atr,spread_pts,vwap_dist,regime);
      string blocker;
      double recent_range_price=(rates[i].high-rates[i].low);
      bool allow=(or_complete && have_or && nf.Allow(spread_pts,InpMaxSpreadPoints,atr,InpMinATR,atr_points,vwap_dist,InpMaxVWAPDistancePoints,recent_range_price,blocker));
      if(!or_complete)
         blocker="BLOCK_BUILDING_OPENING_RANGE";
      else if(!have_or)
         blocker="BLOCK_OR_UNAVAILABLE";
      else if(allow)
         blocker="NONE";

      Print(StringFormat("[%s] SessionStart=%s ORH=%.2f ORL=%.2f ORM=%.2f ORW=%.2f VWAP=%.2f Regime=%s(%s) ORB=%s MR=%s Score[r=%d c=%d t=%d e=%d v=%d n=%d tot=%d] Blocker=%s",
                         TimeToString(ts,TIME_DATE|TIME_MINUTES),
                         TimeToString(ss.session_start,TIME_DATE|TIME_MINUTES),
                         (have_or?or_data.high:0.0),(have_or?or_data.low:0.0),(have_or?or_data.midpoint:0.0),(have_or?or_data.width:0.0),
                         vwap.Value(),XDF_RegimeToString((int)regime),regime_reason,(orb.valid?"Y":"N"),(mr.valid?"Y":"N"),
                         sb.range_quality,sb.context_quality,sb.trigger_quality,sb.execution_quality,sb.vwap_quality,sb.noise_penalty,sb.total,
                         (allow?"NONE":blocker)));
     }
   IndicatorRelease(atr_handle);
   IndicatorRelease(m15_fast_handle);
   IndicatorRelease(m15_slow_handle);
  }
