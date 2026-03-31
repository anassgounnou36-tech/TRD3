#ifndef XAUDAILYFLOW_MEANREVERSIONSIGNAL_MQH
#define XAUDAILYFLOW_MEANREVERSIONSIGNAL_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFMeanReversionSignal
  {
public:
   XDFSignal Evaluate(const string symbol,const XDFOpeningRange &or_data,double vwap,double atr)
     {
      XDFSignal s;
      ZeroMemory(s);
      s.family=SETUP_MEAN_REVERSION;
      if(!or_data.valid || atr<=0.0)
         return(s);

      MqlRates rates[];
      ArraySetAsSeries(rates,true);
      if(CopyRates(symbol,PERIOD_M5,0,5,rates)<5)
         return(s);

      MqlRates latest=rates[1];
      MqlRates prev=rates[2];
      double min_sweep=atr*0.20;

      if(prev.low<or_data.low-min_sweep && latest.close>or_data.low && latest.close<or_data.high)
        {
         double body=MathAbs(latest.close-latest.open);
         if(body>=(latest.high-latest.low)*0.35)
           {
            s.valid=true; s.direction=1; s.reason="Failed OR downside reclaim";
            s.entry=SymbolInfoDouble(symbol,SYMBOL_ASK);
            s.stop=prev.low-atr*0.20;
            double target=0.0;
            if(vwap>s.entry) target=vwap;
            if(or_data.midpoint>s.entry && (target==0.0 || or_data.midpoint<target)) target=or_data.midpoint;
            s.tp_hint=target;
            if(s.tp_hint<=s.entry || s.tp_hint==0.0)
               s.tp_hint=s.entry+atr*0.9;
            return(s);
           }
        }

      if(prev.high>or_data.high+min_sweep && latest.close<or_data.high && latest.close>or_data.low)
        {
         double body=MathAbs(latest.close-latest.open);
         if(body>=(latest.high-latest.low)*0.35)
           {
            s.valid=true; s.direction=-1; s.reason="Failed OR upside reclaim";
            s.entry=SymbolInfoDouble(symbol,SYMBOL_BID);
            s.stop=prev.high+atr*0.20;
            double target=0.0;
            if(vwap<s.entry) target=vwap;
            if(or_data.midpoint<s.entry && (target==0.0 || or_data.midpoint>target)) target=or_data.midpoint;
            s.tp_hint=target;
            if(s.tp_hint>=s.entry || s.tp_hint==0.0)
               s.tp_hint=s.entry-atr*0.9;
            return(s);
           }
        }

      return(s);
     }
  };

#endif
