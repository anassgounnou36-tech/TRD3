#ifndef XAUDAILYFLOW_ORBSIGNAL_MQH
#define XAUDAILYFLOW_ORBSIGNAL_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFORBSignal
  {
public:
   XDFSignal EvaluateFromBar(const MqlRates &b,double entry_long,double entry_short,const XDFOpeningRange &or_data,double vwap,double atr,bool ema_long_ok,bool ema_short_ok,double min_stop_distance)
     {
      XDFSignal s;
      ZeroMemory(s);
      s.family=SETUP_ORB_CONTINUATION;
      if(!or_data.valid || atr<=0.0)
         return(s);

      double body=MathAbs(b.close-b.open);
      double range=b.high-b.low;
      if(range<=0.0)
         return(s);

      bool strong=(body/range)>=0.45;
      if(!strong)
         return(s);

      if(b.close>or_data.high && b.close>vwap && ema_long_ok && (b.close-or_data.high)<(atr*1.5))
        {
         s.valid=true; s.direction=1; s.reason="ORB long continuation";
         s.entry=entry_long;
         double base_stop=or_data.low - atr*0.35;
         s.stop=MathMin(base_stop,s.entry-min_stop_distance);
         s.tp_hint=s.entry + atr*1.1;
         s.stop_distance=MathAbs(s.entry-s.stop);
         s.target_distance=MathAbs(s.tp_hint-s.entry);
         s.trigger_body_ratio=(range>0.0 ? body/range : 0.0);
         s.vwap_side_ok=(b.close>vwap);
         return(s);
        }

      if(b.close<or_data.low && b.close<vwap && ema_short_ok && (or_data.low-b.close)<(atr*1.5))
        {
         s.valid=true; s.direction=-1; s.reason="ORB short continuation";
         s.entry=entry_short;
         double base_stop=or_data.high + atr*0.35;
         s.stop=MathMax(base_stop,s.entry+min_stop_distance);
         s.tp_hint=s.entry - atr*1.1;
         s.stop_distance=MathAbs(s.entry-s.stop);
         s.target_distance=MathAbs(s.tp_hint-s.entry);
         s.trigger_body_ratio=(range>0.0 ? body/range : 0.0);
         s.vwap_side_ok=(b.close<vwap);
         return(s);
        }

      return(s);
     }

   XDFSignal Evaluate(const string symbol,const XDFOpeningRange &or_data,double vwap,double atr,bool ema_long_ok,bool ema_short_ok,double min_stop_distance)
     {
      MqlRates rates[];
      ArraySetAsSeries(rates,true);
      if(CopyRates(symbol,PERIOD_M5,0,4,rates)<4)
        {
         XDFSignal empty;
         ZeroMemory(empty);
         empty.family=SETUP_ORB_CONTINUATION;
         return(empty);
        }

      return(EvaluateFromBar(rates[1],SymbolInfoDouble(symbol,SYMBOL_ASK),SymbolInfoDouble(symbol,SYMBOL_BID),or_data,vwap,atr,ema_long_ok,ema_short_ok,min_stop_distance));
     }
  };

#endif
