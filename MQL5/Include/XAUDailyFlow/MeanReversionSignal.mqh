#ifndef XAUDAILYFLOW_MEANREVERSIONSIGNAL_MQH
#define XAUDAILYFLOW_MEANREVERSIONSIGNAL_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFMeanReversionSignal
  {
public:
   bool IsBetter(const XDFSignal &candidate,const XDFSignal &current_best)
     {
      if(!candidate.valid)
         return(false);
      if(!current_best.valid)
         return(true);
      if(candidate.subtype_quality>current_best.subtype_quality)
         return(true);
      if(candidate.subtype_quality==current_best.subtype_quality && candidate.reclaim_window_quality>current_best.reclaim_window_quality)
         return(true);
      return(false);
     }

   XDFSignal BuildSignal(const int direction,const string reason,const int subtype_quality,const int confirmation_quality,const int reclaim_window_quality,const int level_hold_quality,const MqlRates &trigger,const double entry,const double stop,const double tp,const double vwap)
     {
      XDFSignal s;
      ZeroMemory(s);
      s.valid=true;
      s.family=SETUP_MEAN_REVERSION;
      s.direction=direction;
      s.reason=reason;
      s.entry=entry;
      s.stop=stop;
      s.tp_hint=tp;
      s.stop_distance=MathAbs(entry-stop);
      s.target_distance=MathAbs(tp-entry);
      double range=(trigger.high-trigger.low);
      double body=MathAbs(trigger.close-trigger.open);
      s.trigger_body_ratio=(range>0.0?body/range:0.0);
      s.vwap_side_ok=(direction>0?vwap>=entry:vwap<=entry);
      s.subtype_quality=subtype_quality;
      s.retest_quality=0;
      s.confirmation_quality=confirmation_quality;
      s.reclaim_window_quality=reclaim_window_quality;
      s.level_hold_quality=level_hold_quality;
      s.extension_penalty=0;
      return(s);
     }

   XDFSignal EvaluateFromBars(const MqlRates &latest,const MqlRates &prev,double entry_long,double entry_short,const XDFOpeningRange &or_data,double vwap,double atr)
     {
      XDFSignal s;
      ZeroMemory(s);
      s.family=SETUP_MEAN_REVERSION;
      if(!or_data.valid || atr<=0.0)
         return(s);

      double min_sweep=atr*0.20;

      if(prev.low<or_data.low-min_sweep && latest.close>or_data.low && latest.close<or_data.high)
        {
         double body=MathAbs(latest.close-latest.open);
         if(body>=(latest.high-latest.low)*0.35)
           {
            s.valid=true; s.direction=1; s.reason="Failed OR downside reclaim";
            s.entry=entry_long;
            s.stop=prev.low-atr*0.20;
            double target=0.0;
            if(vwap>s.entry) target=vwap;
            if(or_data.midpoint>s.entry && (target==0.0 || or_data.midpoint<target)) target=or_data.midpoint;
            s.tp_hint=target;
            if(s.tp_hint<=s.entry || s.tp_hint==0.0)
               s.tp_hint=s.entry+atr*0.9;
            s.stop_distance=MathAbs(s.entry-s.stop);
            s.target_distance=MathAbs(s.tp_hint-s.entry);
            s.trigger_body_ratio=((latest.high-latest.low)>0.0 ? body/(latest.high-latest.low) : 0.0);
            s.vwap_side_ok=(vwap>=s.entry);
            return(s);
           }
        }

      if(prev.high>or_data.high+min_sweep && latest.close<or_data.high && latest.close>or_data.low)
        {
         double body=MathAbs(latest.close-latest.open);
         if(body>=(latest.high-latest.low)*0.35)
           {
            s.valid=true; s.direction=-1; s.reason="Failed OR upside reclaim";
            s.entry=entry_short;
            s.stop=prev.high+atr*0.20;
            double target=0.0;
            if(vwap<s.entry) target=vwap;
            if(or_data.midpoint<s.entry && (target==0.0 || or_data.midpoint>target)) target=or_data.midpoint;
            s.tp_hint=target;
            if(s.tp_hint>=s.entry || s.tp_hint==0.0)
               s.tp_hint=s.entry-atr*0.9;
            s.stop_distance=MathAbs(s.entry-s.stop);
            s.target_distance=MathAbs(s.tp_hint-s.entry);
            s.trigger_body_ratio=((latest.high-latest.low)>0.0 ? body/(latest.high-latest.low) : 0.0);
            s.vwap_side_ok=(vwap<=s.entry);
            return(s);
           }
        }

       return(s);
     }

   XDFSignal EvaluateAt(const string symbol,
                        const int shift,
                        const XDFOpeningRange &or_data,
                        double vwap,
                        double atr,
                        double entry_long,
                        double entry_short)
     {
      XDFSignal best;
      ZeroMemory(best);
      best.family=SETUP_MEAN_REVERSION;
      if(!or_data.valid || atr<=0.0 || shift<1)
         return(best);

      MqlRates bars[];
      ArraySetAsSeries(bars,true);
      if(CopyRates(symbol,PERIOD_M5,shift,7,bars)<4)
         return(best);

      double min_sweep=atr*0.15;
      XDFSignal candidate;

      // A) Immediate sweep + reclaim
      if(bars[1].low<or_data.low-min_sweep && bars[0].close>or_data.low && bars[0].close<or_data.high)
        {
         double stop=bars[1].low-atr*0.20;
         double tp=(or_data.midpoint>entry_long?or_data.midpoint:entry_long+atr*0.9);
         candidate=BuildSignal(1,"MR_IMMEDIATE_SWEEP_RECLAIM",26,16,20,10,bars[0],entry_long,stop,tp,vwap);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(bars[1].high>or_data.high+min_sweep && bars[0].close<or_data.high && bars[0].close>or_data.low)
        {
         double stop=bars[1].high+atr*0.20;
         double tp=(or_data.midpoint<entry_short?or_data.midpoint:entry_short-atr*0.9);
         candidate=BuildSignal(-1,"MR_IMMEDIATE_SWEEP_RECLAIM",26,16,20,10,bars[0],entry_short,stop,tp,vwap);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      // B) Failed break + next-bar confirm
      if(bars[2].low<or_data.low-min_sweep && bars[1].close<=or_data.low+atr*0.05 && bars[0].close>or_data.low)
        {
         double stop=bars[2].low-atr*0.15;
         candidate=BuildSignal(1,"MR_FAILED_BREAK_CONFIRM",24,20,14,12,bars[0],entry_long,stop,entry_long+atr*0.95,vwap);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(bars[2].high>or_data.high+min_sweep && bars[1].close>=or_data.high-atr*0.05 && bars[0].close<or_data.high)
        {
         double stop=bars[2].high+atr*0.15;
         candidate=BuildSignal(-1,"MR_FAILED_BREAK_CONFIRM",24,20,14,12,bars[0],entry_short,stop,entry_short-atr*0.95,vwap);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      // C) Delayed reclaim within short window
      if(bars[3].low<or_data.low-min_sweep && (bars[1].close>or_data.low || bars[0].close>or_data.low) && bars[0].close<or_data.high)
        {
         double stop=bars[3].low-atr*0.20;
         candidate=BuildSignal(1,"MR_DELAYED_RECLAIM",22,14,18,10,bars[0],entry_long,stop,entry_long+atr*0.85,vwap);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(bars[3].high>or_data.high+min_sweep && (bars[1].close<or_data.high || bars[0].close<or_data.high) && bars[0].close>or_data.low)
        {
         double stop=bars[3].high+atr*0.20;
         candidate=BuildSignal(-1,"MR_DELAYED_RECLAIM",22,14,18,10,bars[0],entry_short,stop,entry_short-atr*0.85,vwap);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      // D) Reclaim + midpoint / VWAP confirm
      if(bars[1].close>or_data.low && bars[1].close<or_data.high && (bars[0].close>or_data.midpoint || bars[0].close>vwap))
        {
         double stop=MathMin(bars[1].low,bars[2].low)-atr*0.12;
         candidate=BuildSignal(1,"MR_RECLAIM_CONFIRM_MID_VWAP",21,18,12,14,bars[0],entry_long,stop,entry_long+atr*0.90,vwap);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(bars[1].close<or_data.high && bars[1].close>or_data.low && (bars[0].close<or_data.midpoint || bars[0].close<vwap))
        {
         double stop=MathMax(bars[1].high,bars[2].high)+atr*0.12;
         candidate=BuildSignal(-1,"MR_RECLAIM_CONFIRM_MID_VWAP",21,18,12,14,bars[0],entry_short,stop,entry_short-atr*0.90,vwap);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      return(best);
     }

   XDFSignal Evaluate(const string symbol,const XDFOpeningRange &or_data,double vwap,double atr)
      {
      return(EvaluateAt(symbol,1,or_data,vwap,atr,SymbolInfoDouble(symbol,SYMBOL_ASK),SymbolInfoDouble(symbol,SYMBOL_BID)));
      }
  };

#endif
