#ifndef XAUDAILYFLOW_ORBSIGNAL_MQH
#define XAUDAILYFLOW_ORBSIGNAL_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFORBSignal
  {
public:
   double ExtensionPenalty(const double ext,const double atr)
     {
      if(atr<=0.0 || ext<=atr*1.3)
         return(0.0);
      return((ext-atr*1.3)/atr*8.0);
     }

   bool IsBetter(const XDFSignal &candidate,const XDFSignal &current_best)
     {
      if(!candidate.valid)
         return(false);
      if(!current_best.valid)
         return(true);
      if(candidate.subtype_quality>current_best.subtype_quality)
         return(true);
      if(candidate.subtype_quality==current_best.subtype_quality && candidate.trigger_body_ratio>current_best.trigger_body_ratio)
         return(true);
      return(false);
     }

   XDFSignal BuildSignal(const int direction,const string subtype,const int subtype_quality,const int retest_quality,const int confirmation_quality,const int level_hold_quality,const int raw_context_quality,const MqlRates &trigger,const double entry,const double stop,const double tp,const double vwap,const double extension_penalty)
     {
      XDFSignal s;
      ZeroMemory(s);
      s.valid=true;
      s.family=SETUP_ORB_CONTINUATION;
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
      s.vwap_side_ok=(direction>0?trigger.close>vwap:trigger.close<vwap);
      s.subtype_quality=subtype_quality;
      s.retest_quality=retest_quality;
      s.confirmation_quality=confirmation_quality;
      s.reclaim_window_quality=0;
      s.level_hold_quality=level_hold_quality;
      s.extension_penalty=(int)MathRound(extension_penalty);
      s.reason_invalid="";
      s.raw_trigger_quality=(int)MathRound(s.trigger_body_ratio*100.0);
      s.raw_context_quality=raw_context_quality;
      s.raw_extension_penalty=(int)MathRound(extension_penalty);
      s.raw_structure_quality=subtype_quality+retest_quality+confirmation_quality+level_hold_quality;
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
                        bool ema_long_ok,
                        bool ema_short_ok,
                        double min_stop_distance,
                        double entry_long,
                        double entry_short)
     {
      XDFSignal best;
      ZeroMemory(best);
      best.family=SETUP_ORB_CONTINUATION;
      best.subtype="NONE";
      if(!or_data.valid || atr<=0.0 || shift<1)
        {
         MarkInvalid(best,"invalid_or_or_atr_or_shift");
         return(best);
        }

      MqlRates bars[];
      ArraySetAsSeries(bars,true);
      if(CopyRates(symbol,PERIOD_M5,shift,6,bars)<4)
        {
         MarkInvalid(best,"insufficient_closed_bars");
         return(best);
        }

      MqlRates b0=bars[0];
      MqlRates b1=bars[1];
      MqlRates b2=bars[2];
      double ext_limit=atr*2.0;
      double base_tp=atr*1.15;

      XDFSignal candidate;

      // A) ORB_DIRECT_BREAK
      double range0=b0.high-b0.low;
      double body0=MathAbs(b0.close-b0.open);
      bool body_ok=(range0>0.0 && (body0/range0)>=0.30);
      if(body_ok && ema_long_ok && b0.close>or_data.high && b0.close>vwap)
        {
         double ext=(b0.close-or_data.high);
         if(ext<ext_limit*1.1)
           {
            double stop=MathMin(or_data.low-atr*0.30,entry_long-min_stop_distance);
            double tp=entry_long+base_tp;
            candidate=BuildSignal(1,"ORB_DIRECT_BREAK",26,0,18,12,(ema_long_ok?15:8),b0,entry_long,stop,tp,vwap,ExtensionPenalty(ext,atr));
            if(IsBetter(candidate,best))
               best=candidate;
           }
        }
      if(body_ok && ema_short_ok && b0.close<or_data.low && b0.close<vwap)
        {
         double ext=(or_data.low-b0.close);
         if(ext<ext_limit*1.1)
           {
            double stop=MathMax(or_data.high+atr*0.30,entry_short+min_stop_distance);
            double tp=entry_short-base_tp;
            candidate=BuildSignal(-1,"ORB_DIRECT_BREAK",26,0,18,12,(ema_short_ok?15:8),b0,entry_short,stop,tp,vwap,ExtensionPenalty(ext,atr));
            if(IsBetter(candidate,best))
               best=candidate;
           }
        }

      // B) ORB_BREAK_RETEST_HOLD (allow retest on b1 or b0)
      if(ema_long_ok && (b2.close>or_data.high || b1.close>or_data.high) &&
         ((b1.low>=or_data.high-atr*0.24 && b0.close>or_data.high) || (b0.low>=or_data.high-atr*0.24 && b0.close>or_data.high)))
        {
          double stop=MathMin(or_data.low-atr*0.25,entry_long-min_stop_distance);
          candidate=BuildSignal(1,"ORB_BREAK_RETEST_HOLD",25,19,15,16,(ema_long_ok?14:8),b0,entry_long,stop,entry_long+atr*1.05,vwap,0.0);
          if(IsBetter(candidate,best))
             best=candidate;
        }
      if(ema_short_ok && (b2.close<or_data.low || b1.close<or_data.low) &&
         ((b1.high<=or_data.low+atr*0.24 && b0.close<or_data.low) || (b0.high<=or_data.low+atr*0.24 && b0.close<or_data.low)))
        {
          double stop=MathMax(or_data.high+atr*0.25,entry_short+min_stop_distance);
          candidate=BuildSignal(-1,"ORB_BREAK_RETEST_HOLD",25,19,15,16,(ema_short_ok?14:8),b0,entry_short,stop,entry_short-atr*1.05,vwap,0.0);
          if(IsBetter(candidate,best))
             best=candidate;
        }

      // C) ORB_TWO_BAR_CONFIRM
      if(ema_long_ok && b1.close>=or_data.high-atr*0.14 && b0.close>or_data.high && b0.close>b1.close)
        {
          double stop=MathMin(or_data.low-atr*0.30,entry_long-min_stop_distance);
          candidate=BuildSignal(1,"ORB_TWO_BAR_CONFIRM",23,8,21,12,(ema_long_ok?14:8),b0,entry_long,stop,entry_long+atr*1.2,vwap,0.0);
          if(IsBetter(candidate,best))
             best=candidate;
        }
      if(ema_short_ok && b1.close<=or_data.low+atr*0.14 && b0.close<or_data.low && b0.close<b1.close)
        {
          double stop=MathMax(or_data.high+atr*0.30,entry_short+min_stop_distance);
          candidate=BuildSignal(-1,"ORB_TWO_BAR_CONFIRM",23,8,21,12,(ema_short_ok?14:8),b0,entry_short,stop,entry_short-atr*1.2,vwap,0.0);
          if(IsBetter(candidate,best))
             best=candidate;
        }

      // D) ORB_BREAK_PAUSE_CONTINUE
      if(ema_long_ok && b2.close>or_data.high && b1.low>or_data.high-atr*0.20 && b1.close>or_data.high-atr*0.08 && b0.close>or_data.high)
        {
          double stop=MathMin(or_data.low-atr*0.25,entry_long-min_stop_distance);
          candidate=BuildSignal(1,"ORB_BREAK_PAUSE_CONTINUE",22,12,16,20,(ema_long_ok?13:8),b0,entry_long,stop,entry_long+atr*1.0,vwap,0.0);
          if(IsBetter(candidate,best))
             best=candidate;
        }
      if(ema_short_ok && b2.close<or_data.low && b1.high<or_data.low+atr*0.20 && b1.close<or_data.low+atr*0.08 && b0.close<or_data.low)
        {
          double stop=MathMax(or_data.high+atr*0.25,entry_short+min_stop_distance);
          candidate=BuildSignal(-1,"ORB_BREAK_PAUSE_CONTINUE",22,12,16,20,(ema_short_ok?13:8),b0,entry_short,stop,entry_short-atr*1.0,vwap,0.0);
          if(IsBetter(candidate,best))
             best=candidate;
        }

      if(!best.valid)
         MarkInvalid(best,"no_orb_subtype_match");
      return(best);
     }

   XDFSignal Evaluate(const string symbol,const XDFOpeningRange &or_data,double vwap,double atr,bool ema_long_ok,bool ema_short_ok,double min_stop_distance)
     {
      return(EvaluateAt(symbol,1,or_data,vwap,atr,ema_long_ok,ema_short_ok,min_stop_distance,SymbolInfoDouble(symbol,SYMBOL_ASK),SymbolInfoDouble(symbol,SYMBOL_BID)));
     }
  };

#endif
