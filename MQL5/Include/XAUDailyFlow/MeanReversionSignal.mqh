#ifndef XAUDAILYFLOW_MEANREVERSIONSIGNAL_MQH
#define XAUDAILYFLOW_MEANREVERSIONSIGNAL_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFMeanReversionSignal
  {
private:
   double XDF_LongMRStructuralStop(const double sweep_low,const double atr,const double entry)
     {
      double stop=sweep_low-atr*0.08;
      if(entry-stop<atr*0.05)
         stop=entry-atr*0.05;
      return(stop);
     }
   double XDF_ShortMRStructuralStop(const double sweep_high,const double atr,const double entry)
     {
      double stop=sweep_high+atr*0.08;
      if(stop-entry<atr*0.05)
         stop=entry+atr*0.05;
      return(stop);
     }
   bool XDF_ValidateMRGeometry(XDFSignal &s,const string subtype,const double atr,const double min_rr)
     {
      if(!s.valid || atr<=0.0 || s.stop_distance<=0.0 || s.target_distance<=0.0)
        {
         s.valid=false;
         s.reason_invalid="mr_geometry_invalid_inputs";
         return(false);
        }
      if(s.stop_distance>atr*0.85)
        {
         s.valid=false;
         s.reason_invalid=StringFormat("mr_stop_cap_fail subtype=%s stop=%.2f cap=%.2f",subtype,s.stop_distance,atr*0.85);
         return(false);
        }
      if(s.target_distance<=s.stop_distance)
        {
         s.valid=false;
         s.reason_invalid=StringFormat("mr_target_le_stop subtype=%s target=%.2f stop=%.2f",subtype,s.target_distance,s.stop_distance);
         return(false);
        }
      double rr=(s.stop_distance>0.0?s.target_distance/s.stop_distance:0.0);
      if(rr<min_rr)
        {
         s.valid=false;
         s.reason_invalid=StringFormat("mr_rr_fail subtype=%s rr=%.2f min=%.2f",subtype,rr,min_rr);
         return(false);
        }
      return(true);
     }
   double XDF_LongMRTarget(const XDFOpeningRange &or_data,const double vwap,const double entry,const double stop,const double min_rr)
     {
      double risk=MathAbs(entry-stop);
      double required=entry+risk*min_rr;
      double t1=or_data.midpoint;
      double t2=vwap;
      double t3=(or_data.high-or_data.low>0.0?or_data.high-(or_data.high-or_data.low)*0.20:or_data.high);
      double structural=MathMax(t1,MathMax(t2,t3));
      return(MathMax(required,structural));
     }
   double XDF_ShortMRTarget(const XDFOpeningRange &or_data,const double vwap,const double entry,const double stop,const double min_rr)
     {
      double risk=MathAbs(entry-stop);
      double required=entry-risk*min_rr;
      double t1=or_data.midpoint;
      double t2=vwap;
      double t3=(or_data.high-or_data.low>0.0?or_data.low+(or_data.high-or_data.low)*0.20:or_data.low);
      double structural=MathMin(t1,MathMin(t2,t3));
      return(MathMin(required,structural));
     }
public:
   bool IsBetter(const XDFSignal &candidate,const XDFSignal &current_best,const double point,const double spread_points,const double expected_slippage_points)
     {
      if(!candidate.valid)
         return(false);
      if(!current_best.valid)
         return(true);
      double c_stop=(point>0.0?candidate.stop_distance/point:0.0);
      double c_target=(point>0.0?candidate.target_distance/point:0.0);
      double b_stop=(point>0.0?current_best.stop_distance/point:0.0);
      double b_target=(point>0.0?current_best.target_distance/point:0.0);
      double c_rr=(c_stop>0.0?c_target/c_stop:0.0);
      double b_rr=(b_stop>0.0?b_target/b_stop:0.0);
      if(c_rr>b_rr+0.001)
         return(true);
      if(c_rr+0.001<b_rr)
         return(false);
      double c_net=c_target-spread_points-expected_slippage_points;
      double b_net=b_target-spread_points-expected_slippage_points;
      if(c_net>b_net+0.1)
         return(true);
      if(c_net+0.1<b_net)
         return(false);
      if(candidate.subtype_quality>current_best.subtype_quality)
         return(true);
      if(candidate.subtype_quality<current_best.subtype_quality)
         return(false);
      return(candidate.extension_penalty<current_best.extension_penalty);
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
                        double entry_short,
                        const double point,
                        const double spread_points,
                        const double expected_slippage_points)
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

      if(bars[1].low<or_data.low-min_sweep && bars[0].close>or_data.low && bars[0].close<or_data.high)
        {
         double stop=XDF_LongMRStructuralStop(bars[1].low,atr,entry_long);
         double tp=XDF_LongMRTarget(or_data,vwap,entry_long,stop,1.00);
         candidate=BuildSignal(1,"MR_IMMEDIATE_SWEEP_RECLAIM",26,16,20,10,13,bars[0],entry_long,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_IMMEDIATE_SWEEP_RECLAIM",atr,1.00);
         if(IsBetter(candidate,best,point,spread_points,expected_slippage_points))
            best=candidate;
        }
      if(bars[1].high>or_data.high+min_sweep && bars[0].close<or_data.high && bars[0].close>or_data.low)
        {
         double stop=XDF_ShortMRStructuralStop(bars[1].high,atr,entry_short);
         double tp=XDF_ShortMRTarget(or_data,vwap,entry_short,stop,1.00);
         candidate=BuildSignal(-1,"MR_IMMEDIATE_SWEEP_RECLAIM",26,16,20,10,13,bars[0],entry_short,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_IMMEDIATE_SWEEP_RECLAIM",atr,1.00);
         if(IsBetter(candidate,best,point,spread_points,expected_slippage_points))
            best=candidate;
        }

      if(bars[2].low<or_data.low-min_sweep && bars[1].close<=or_data.low+atr*0.05 && bars[0].close>or_data.low)
        {
         double stop=XDF_LongMRStructuralStop(bars[2].low,atr,entry_long);
         double tp=XDF_LongMRTarget(or_data,vwap,entry_long,stop,1.05);
         candidate=BuildSignal(1,"MR_FAILED_BREAK_NEXT_BAR_CONFIRM",24,20,14,12,12,bars[0],entry_long,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_FAILED_BREAK_NEXT_BAR_CONFIRM",atr,1.05);
         if(IsBetter(candidate,best,point,spread_points,expected_slippage_points))
            best=candidate;
        }
      if(bars[2].high>or_data.high+min_sweep && bars[1].close>=or_data.high-atr*0.05 && bars[0].close<or_data.high)
        {
         double stop=XDF_ShortMRStructuralStop(bars[2].high,atr,entry_short);
         double tp=XDF_ShortMRTarget(or_data,vwap,entry_short,stop,1.05);
         candidate=BuildSignal(-1,"MR_FAILED_BREAK_NEXT_BAR_CONFIRM",24,20,14,12,12,bars[0],entry_short,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_FAILED_BREAK_NEXT_BAR_CONFIRM",atr,1.05);
         if(IsBetter(candidate,best,point,spread_points,expected_slippage_points))
            best=candidate;
        }

      if(bars[3].low<or_data.low-min_sweep && (bars[1].close>or_data.low || bars[0].close>or_data.low) && bars[0].close<or_data.high)
        {
         double stop=XDF_LongMRStructuralStop(bars[3].low,atr,entry_long);
         double tp=XDF_LongMRTarget(or_data,vwap,entry_long,stop,1.00);
         candidate=BuildSignal(1,"MR_DELAYED_RECLAIM_WINDOW",23,14,18,10,11,bars[0],entry_long,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_DELAYED_RECLAIM_WINDOW",atr,1.00);
         if(IsBetter(candidate,best,point,spread_points,expected_slippage_points))
            best=candidate;
        }
      if(bars[3].high>or_data.high+min_sweep && (bars[1].close<or_data.high || bars[0].close<or_data.high) && bars[0].close>or_data.low)
        {
         double stop=XDF_ShortMRStructuralStop(bars[3].high,atr,entry_short);
         double tp=XDF_ShortMRTarget(or_data,vwap,entry_short,stop,1.00);
         candidate=BuildSignal(-1,"MR_DELAYED_RECLAIM_WINDOW",23,14,18,10,11,bars[0],entry_short,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_DELAYED_RECLAIM_WINDOW",atr,1.00);
         if(IsBetter(candidate,best,point,spread_points,expected_slippage_points))
            best=candidate;
        }

      if(bars[1].close>or_data.low && bars[1].close<or_data.high && (bars[0].close>or_data.midpoint || bars[0].close>vwap))
        {
         double stop=XDF_LongMRStructuralStop(MathMin(bars[1].low,bars[2].low),atr,entry_long);
         double tp=XDF_LongMRTarget(or_data,vwap,entry_long,stop,1.00);
         candidate=BuildSignal(1,"MR_RECLAIM_THEN_MIDPOINT_CONFIRM",22,18,12,14,12,bars[0],entry_long,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_RECLAIM_THEN_MIDPOINT_CONFIRM",atr,1.00);
         if(IsBetter(candidate,best,point,spread_points,expected_slippage_points))
            best=candidate;
        }
      if(bars[1].close<or_data.high && bars[1].close>or_data.low && (bars[0].close<or_data.midpoint || bars[0].close<vwap))
        {
         double stop=XDF_ShortMRStructuralStop(MathMax(bars[1].high,bars[2].high),atr,entry_short);
         double tp=XDF_ShortMRTarget(or_data,vwap,entry_short,stop,1.00);
         candidate=BuildSignal(-1,"MR_RECLAIM_THEN_MIDPOINT_CONFIRM",22,18,12,14,12,bars[0],entry_short,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_RECLAIM_THEN_MIDPOINT_CONFIRM",atr,1.00);
         if(IsBetter(candidate,best,point,spread_points,expected_slippage_points))
            best=candidate;
        }

      if(bars[2].close>or_data.high && bars[1].close>or_data.high-atr*0.05 && bars[0].close<or_data.high)
        {
         double stop=XDF_ShortMRStructuralStop(MathMax(bars[2].high,bars[1].high),atr,entry_short);
         double tp=XDF_ShortMRTarget(or_data,vwap,entry_short,stop,1.05);
         candidate=BuildSignal(-1,"MR_FALSE_BREAK_HOLD_FAIL",22,17,13,15,11,bars[0],entry_short,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_FALSE_BREAK_HOLD_FAIL",atr,1.05);
         if(IsBetter(candidate,best,point,spread_points,expected_slippage_points))
            best=candidate;
        }
      if(bars[2].close<or_data.low && bars[1].close<or_data.low+atr*0.05 && bars[0].close>or_data.low)
        {
         double stop=XDF_LongMRStructuralStop(MathMin(bars[2].low,bars[1].low),atr,entry_long);
         double tp=XDF_LongMRTarget(or_data,vwap,entry_long,stop,1.05);
         candidate=BuildSignal(1,"MR_FALSE_BREAK_HOLD_FAIL",22,17,13,15,11,bars[0],entry_long,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_FALSE_BREAK_HOLD_FAIL",atr,1.05);
         if(IsBetter(candidate,best,point,spread_points,expected_slippage_points))
            best=candidate;
        }

      if(!best.valid)
         MarkInvalid(best,"no_mr_subtype_match");
      return(best);
     }

   XDFSignal Evaluate(const string symbol,const XDFOpeningRange &or_data,double vwap,double atr)
      {
      return(EvaluateAt(symbol,1,or_data,vwap,atr,SymbolInfoDouble(symbol,SYMBOL_ASK),SymbolInfoDouble(symbol,SYMBOL_BID),SymbolInfoDouble(symbol,SYMBOL_POINT),0.0,0.0));
      }
  };

#endif
