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

input string InpSymbol = "";
input ENUM_TIMEFRAMES InpTF = PERIOD_M5;
input int InpBars = 20;
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
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int copied=CopyRates(sym,InpTF,0,InpBars,rates);
   if(copied<=0)
     {
      Print("Bar audit failed for symbol ",sym);
      return;
     }

   Print("=== XAUDailyFlow Bar Audit ===");
   Print("Symbol=",sym," TF=",EnumToString(InpTF)," Bars=",copied);

   XDFSessionConfig cfg;
   cfg.start_hour=InpSessionStartHour;
   cfg.start_minute=InpSessionStartMinute;
   cfg.or_minutes=InpSessionORMinutes;
   cfg.trade_minutes=120;
   cfg.id=SESSION_LONDON;
   cfg.name="AuditSession";

   XDFSessionState ss;
   XDF_BuildSessionState(cfg,TimeCurrent(),ss);
   XDFOpeningRangeEngine or_engine;
   or_engine.Init(sym);
   XDFOpeningRange or_data;
   bool have_or=or_engine.Build(ss.session_start,ss.or_end,or_data);

   XDFIndicatorEngine ie;
   ie.Init(sym);
   double atr=ie.ATR();
   double m15s=ie.M15Slope();
   bool m15l=ie.M15EMAAligned(true);
   bool m15sh=ie.M15EMAAligned(false);

   XDFVWAPEngine vwap;
   vwap.Reset(sym,ss.session_start);
   vwap.Update();

   double bid=SymbolInfoDouble(sym,SYMBOL_BID);
   double ask=SymbolInfoDouble(sym,SYMBOL_ASK);
   double mid=(bid+ask)/2.0;
   double spread_pts=0.0;
   double point=SymbolInfoDouble(sym,SYMBOL_POINT);
   if(point>0.0)
      spread_pts=(ask-bid)/point;
   double vwap_dist=(point>0.0 ? MathAbs(mid-vwap.Value())/point : 0.0);

   XDFRegimeEngine re;
   XDFRegime regime=re.Detect(or_data,atr,vwap.Value(),mid,false,m15s,m15l,m15sh);
   XDFORBSignal orb_e;
   XDFMeanReversionSignal mr_e;
   XDFSignal orb=orb_e.Evaluate(sym,or_data,vwap.Value(),atr,ie.EMAAligned(true),ie.EMAAligned(false),point*5.0);
   XDFSignal mr=mr_e.Evaluate(sym,or_data,vwap.Value(),atr);
   XDFSignal chosen=(orb.valid?orb:mr);
   XDFSetupScorer scorer;
   XDFScoreBreakdown sb=scorer.Score(chosen,or_data,atr,spread_pts,vwap_dist,regime);
   XDFNoTradeFilter nf;
   string blocker;
   bool allow=nf.Allow(spread_pts,InpMaxSpreadPoints,atr,InpMinATR,vwap_dist,InpMaxVWAPDistancePoints,blocker);

   Print(StringFormat("SessionStart=%s ORH=%.2f ORL=%.2f ORM=%.2f ORW=%.2f VWAP=%.2f Regime=%d ORB=%s MR=%s Score=%d Blocker=%s",
                      TimeToString(ss.session_start,TIME_DATE|TIME_MINUTES),
                      (have_or?or_data.high:0.0),(have_or?or_data.low:0.0),(have_or?or_data.midpoint:0.0),(have_or?or_data.width:0.0),
                      vwap.Value(),(int)regime,(orb.valid?"Y":"N"),(mr.valid?"Y":"N"),sb.total,(allow?"NONE":blocker)));

   for(int i=copied-1;i>=0;i--)
     {
      Print(TimeToString(rates[i].time,TIME_DATE|TIME_MINUTES),
            " O=",DoubleToString(rates[i].open,_Digits),
            " H=",DoubleToString(rates[i].high,_Digits),
            " L=",DoubleToString(rates[i].low,_Digits),
            " C=",DoubleToString(rates[i].close,_Digits),
            " V=",(long)rates[i].tick_volume);
     }
   ie.Release();
  }
