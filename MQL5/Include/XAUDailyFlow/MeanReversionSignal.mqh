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

   XDFSignal BuildSignal(const int direction,const string subtype,const int subtype_quality,const int confirmation_quality,const int reclaim_window_quality,const int level_hold_quality,const int raw_context_quality,const MqlRates &trigger,const double entry,const double stop,const double tp,const double vwap,const double extension_penalty)
     {
      XDFSignal s;
      ZeroMemory(s);
      s.valid=true;
      s.family=SETUP_MEAN_REVERSION;
      s.direction=direction;
      s.reason=subtype;
      s.subtype=subtype;
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
      s.extension_penalty=(int)MathRound(extension_penalty);
      s.reason_invalid="";
      s.raw_trigger_quality=(int)MathRound(s.trigger_body_ratio*100.0);
      s.raw_context_quality=raw_context_quality;
      s.raw_extension_penalty=(int)MathRound(extension_penalty);
      s.raw_structure_quality=subtype_quality+confirmation_quality+reclaim_window_quality+level_hold_quality;
      return(s);
     }

   void MarkInvalid(XDFSignal &s,const string reason)
     {
      s.valid=false;
      s.reason_invalid=reason;
      if(s.subtype=="")
         s.subtype="NONE";
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
      best.subtype="NONE";
      if(!or_data.valid || atr<=0.0 || shift<1)
        {
         MarkInvalid(best,"invalid_or_or_atr_or_shift");
         return(best);
        }

      MqlRates bars[];
      ArraySetAsSeries(bars,true);
      if(CopyRates(symbol,PERIOD_M5,shift,7,bars)<4)
        {
         MarkInvalid(best,"insufficient_closed_bars");
         return(best);
        }

      double min_sweep=atr*0.15;
      XDFSignal candidate;

      // A) MR_IMMEDIATE_SWEEP_RECLAIM
      if(bars[1].low<or_data.low-min_sweep && bars[0].close>or_data.low && bars[0].close<or_data.high)
        {
         double stop=bars[1].low-atr*0.20;
         double tp=(or_data.midpoint>entry_long?or_data.midpoint:entry_long+atr*0.9);
         candidate=BuildSignal(1,"MR_IMMEDIATE_SWEEP_RECLAIM",26,16,20,10,13,bars[0],entry_long,stop,tp,vwap,0.0);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(bars[1].high>or_data.high+min_sweep && bars[0].close<or_data.high && bars[0].close>or_data.low)
        {
         double stop=bars[1].high+atr*0.20;
         double tp=(or_data.midpoint<entry_short?or_data.midpoint:entry_short-atr*0.9);
         candidate=BuildSignal(-1,"MR_IMMEDIATE_SWEEP_RECLAIM",26,16,20,10,13,bars[0],entry_short,stop,tp,vwap,0.0);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      // B) MR_FAILED_BREAK_NEXT_BAR_CONFIRM
      if(bars[2].low<or_data.low-min_sweep && bars[1].close<=or_data.low+atr*0.05 && bars[0].close>or_data.low)
        {
         double stop=bars[2].low-atr*0.15;
         candidate=BuildSignal(1,"MR_FAILED_BREAK_NEXT_BAR_CONFIRM",24,20,14,12,12,bars[0],entry_long,stop,entry_long+atr*0.95,vwap,0.0);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(bars[2].high>or_data.high+min_sweep && bars[1].close>=or_data.high-atr*0.05 && bars[0].close<or_data.high)
        {
         double stop=bars[2].high+atr*0.15;
         candidate=BuildSignal(-1,"MR_FAILED_BREAK_NEXT_BAR_CONFIRM",24,20,14,12,12,bars[0],entry_short,stop,entry_short-atr*0.95,vwap,0.0);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      // C) MR_DELAYED_RECLAIM_WINDOW
      if(bars[3].low<or_data.low-min_sweep && (bars[1].close>or_data.low || bars[0].close>or_data.low) && bars[0].close<or_data.high)
        {
         double stop=bars[3].low-atr*0.20;
         candidate=BuildSignal(1,"MR_DELAYED_RECLAIM_WINDOW",23,14,18,10,11,bars[0],entry_long,stop,entry_long+atr*0.85,vwap,0.0);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(bars[3].high>or_data.high+min_sweep && (bars[1].close<or_data.high || bars[0].close<or_data.high) && bars[0].close>or_data.low)
        {
         double stop=bars[3].high+atr*0.20;
         candidate=BuildSignal(-1,"MR_DELAYED_RECLAIM_WINDOW",23,14,18,10,11,bars[0],entry_short,stop,entry_short-atr*0.85,vwap,0.0);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      // D) MR_RECLAIM_THEN_MIDPOINT_CONFIRM
      if(bars[1].close>or_data.low && bars[1].close<or_data.high && (bars[0].close>or_data.midpoint || bars[0].close>vwap))
        {
         double stop=MathMin(bars[1].low,bars[2].low)-atr*0.12;
         candidate=BuildSignal(1,"MR_RECLAIM_THEN_MIDPOINT_CONFIRM",22,18,12,14,12,bars[0],entry_long,stop,entry_long+atr*0.90,vwap,0.0);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(bars[1].close<or_data.high && bars[1].close>or_data.low && (bars[0].close<or_data.midpoint || bars[0].close<vwap))
        {
         double stop=MathMax(bars[1].high,bars[2].high)+atr*0.12;
         candidate=BuildSignal(-1,"MR_RECLAIM_THEN_MIDPOINT_CONFIRM",22,18,12,14,12,bars[0],entry_short,stop,entry_short-atr*0.90,vwap,0.0);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      // E) MR_FALSE_BREAK_HOLD_FAIL
      if(bars[2].close>or_data.high && bars[1].close>or_data.high-atr*0.05 && bars[0].close<or_data.high)
        {
         double stop=MathMax(bars[2].high,bars[1].high)+atr*0.10;
         candidate=BuildSignal(-1,"MR_FALSE_BREAK_HOLD_FAIL",22,17,13,15,11,bars[0],entry_short,stop,entry_short-atr*0.92,vwap,0.0);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(bars[2].close<or_data.low && bars[1].close<or_data.low+atr*0.05 && bars[0].close>or_data.low)
        {
         double stop=MathMin(bars[2].low,bars[1].low)-atr*0.10;
         candidate=BuildSignal(1,"MR_FALSE_BREAK_HOLD_FAIL",22,17,13,15,11,bars[0],entry_long,stop,entry_long+atr*0.92,vwap,0.0);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      if(!best.valid)
         MarkInvalid(best,"no_mr_subtype_match");
      return(best);
     }

   XDFSignal Evaluate(const string symbol,const XDFOpeningRange &or_data,double vwap,double atr)
      {
      return(EvaluateAt(symbol,1,or_data,vwap,atr,SymbolInfoDouble(symbol,SYMBOL_ASK),SymbolInfoDouble(symbol,SYMBOL_BID)));
      }
  };

#endif
