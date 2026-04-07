#ifndef XAUDAILYFLOW_MEANREVERSIONSIGNAL_MQH
#define XAUDAILYFLOW_MEANREVERSIONSIGNAL_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFMeanReversionSignal
  {
private:
   void XDF_SetGeometryMetrics(XDFSignal &s,const double point,const double atr,const double or_width,const double spread_points,const double slip_points)
     {
      if(point<=0.0)
         return;
      s.stop_points=s.stop_distance/point;
      s.target_points=s.target_distance/point;
      s.atr_points=(atr>0.0?atr/point:0.0);
      s.or_width_points=(or_width>0.0?or_width/point:0.0);
      s.spread_points=spread_points;
      s.slip_points=slip_points;
      s.gross_rr=(s.stop_points>0.0?s.target_points/s.stop_points:0.0);
      s.net_target_points=s.target_points-spread_points-slip_points;
      s.net_rr=(s.stop_points>0.0?s.net_target_points/s.stop_points:0.0);
     }
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
   bool XDF_ValidateMRGeometry(XDFSignal &s,const string subtype,const XDFRegime regime,const double point,const double atr,const double or_width,const double spread_points,const double slip_points)
      {
       if(!s.valid || point<=0.0 || atr<=0.0)
         {
          s.valid=false;
          s.reason_invalid=StringFormat("MR_GEOMETRY_INVALID_INPUTS source_geom_regime=%d",(int)regime);
          return(false);
         }

       XDF_SetGeometryMetrics(s,point,atr,or_width,spread_points,slip_points);
       XDFGeometryMetrics metrics;
       string reason;
       bool pass=XDF_PassesGeometryPolicy(SETUP_MEAN_REVERSION,subtype,regime,s.stop_points,s.target_points,s.spread_points,s.slip_points,s.atr_points,s.or_width_points,metrics,reason);
       s.gross_rr=metrics.gross_rr;
       s.net_target_points=metrics.net_target_points;
       s.net_rr=metrics.net_rr;
       s.reason=StringFormat("%s source_geom_regime=%d",subtype,(int)regime);
       if(!pass)
         {
          s.valid=false;
          s.reason_invalid=StringFormat("%s source_geom_regime=%d",reason,(int)regime);
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
      double t3=(or_data.high-or_data.low>0.0?or_data.low+(or_data.high-or_data.low)*0.80:or_data.high);
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
   bool IsBetter(const XDFSignal &candidate,const XDFSignal &current_best)
     {
      if(!candidate.valid)
         return(false);
      if(!current_best.valid)
         return(true);
      if(candidate.net_rr>=current_best.net_rr+0.10)
         return(true);
      if(candidate.net_rr<=current_best.net_rr-0.10)
         return(false);
      if(candidate.net_rr>current_best.net_rr+0.001)
         return(true);
      if(candidate.net_rr+0.001<current_best.net_rr)
         return(false);
      if(candidate.net_target_points>current_best.net_target_points+0.1)
         return(true);
      if(candidate.net_target_points+0.1<current_best.net_target_points)
         return(false);
      if(MathAbs(candidate.net_rr-current_best.net_rr)<=0.02 &&
         MathAbs(candidate.net_target_points-current_best.net_target_points)<=0.5)
        {
         if(candidate.stop_points+0.1<current_best.stop_points)
            return(true);
         if(current_best.stop_points+0.1<candidate.stop_points)
            return(false);
        }
      if(candidate.raw_structure_quality>current_best.raw_structure_quality)
         return(true);
      if(candidate.raw_structure_quality<current_best.raw_structure_quality)
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
                         const double expected_slippage_points,
                         const XDFRegime regime)
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
      double or_width=MathMax(or_data.width,atr*0.25);
      XDFSignal candidate;

      if(bars[1].low<or_data.low-min_sweep && bars[0].close>or_data.low && bars[0].close<or_data.high)
        {
         double stop=XDF_LongMRStructuralStop(bars[1].low,atr,entry_long);
         double tp=XDF_LongMRTarget(or_data,vwap,entry_long,stop,1.00);
         candidate=BuildSignal(1,"MR_IMMEDIATE_SWEEP_RECLAIM",26,16,20,10,13,bars[0],entry_long,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_IMMEDIATE_SWEEP_RECLAIM",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(bars[1].high>or_data.high+min_sweep && bars[0].close<or_data.high && bars[0].close>or_data.low)
        {
         double stop=XDF_ShortMRStructuralStop(bars[1].high,atr,entry_short);
         double tp=XDF_ShortMRTarget(or_data,vwap,entry_short,stop,1.00);
         candidate=BuildSignal(-1,"MR_IMMEDIATE_SWEEP_RECLAIM",26,16,20,10,13,bars[0],entry_short,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_IMMEDIATE_SWEEP_RECLAIM",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      if(bars[2].low<or_data.low-min_sweep && bars[1].close<=or_data.low+atr*0.05 && bars[0].close>or_data.low)
        {
         double stop=XDF_LongMRStructuralStop(bars[2].low,atr,entry_long);
         double tp=XDF_LongMRTarget(or_data,vwap,entry_long,stop,1.05);
         candidate=BuildSignal(1,"MR_FAILED_BREAK_NEXT_BAR_CONFIRM",24,20,14,12,12,bars[0],entry_long,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_FAILED_BREAK_NEXT_BAR_CONFIRM",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(bars[2].high>or_data.high+min_sweep && bars[1].close>=or_data.high-atr*0.05 && bars[0].close<or_data.high)
        {
         double stop=XDF_ShortMRStructuralStop(bars[2].high,atr,entry_short);
         double tp=XDF_ShortMRTarget(or_data,vwap,entry_short,stop,1.05);
         candidate=BuildSignal(-1,"MR_FAILED_BREAK_NEXT_BAR_CONFIRM",24,20,14,12,12,bars[0],entry_short,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_FAILED_BREAK_NEXT_BAR_CONFIRM",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      if(bars[3].low<or_data.low-min_sweep && (bars[1].close>or_data.low || bars[0].close>or_data.low) && bars[0].close<or_data.high)
        {
         double stop=XDF_LongMRStructuralStop(bars[3].low,atr,entry_long);
         double tp=XDF_LongMRTarget(or_data,vwap,entry_long,stop,1.00);
         candidate=BuildSignal(1,"MR_DELAYED_RECLAIM_WINDOW",23,14,18,10,11,bars[0],entry_long,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_DELAYED_RECLAIM_WINDOW",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(bars[3].high>or_data.high+min_sweep && (bars[1].close<or_data.high || bars[0].close<or_data.high) && bars[0].close>or_data.low)
        {
         double stop=XDF_ShortMRStructuralStop(bars[3].high,atr,entry_short);
         double tp=XDF_ShortMRTarget(or_data,vwap,entry_short,stop,1.00);
         candidate=BuildSignal(-1,"MR_DELAYED_RECLAIM_WINDOW",23,14,18,10,11,bars[0],entry_short,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_DELAYED_RECLAIM_WINDOW",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      if(bars[1].close>or_data.low && bars[1].close<or_data.high && (bars[0].close>or_data.midpoint || bars[0].close>vwap))
        {
         double stop=XDF_LongMRStructuralStop(MathMin(bars[1].low,bars[2].low),atr,entry_long);
         double tp=XDF_LongMRTarget(or_data,vwap,entry_long,stop,1.00);
         candidate=BuildSignal(1,"MR_RECLAIM_THEN_MIDPOINT_CONFIRM",22,18,12,14,12,bars[0],entry_long,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_RECLAIM_THEN_MIDPOINT_CONFIRM",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(bars[1].close<or_data.high && bars[1].close>or_data.low && (bars[0].close<or_data.midpoint || bars[0].close<vwap))
        {
         double stop=XDF_ShortMRStructuralStop(MathMax(bars[1].high,bars[2].high),atr,entry_short);
         double tp=XDF_ShortMRTarget(or_data,vwap,entry_short,stop,1.00);
         candidate=BuildSignal(-1,"MR_RECLAIM_THEN_MIDPOINT_CONFIRM",22,18,12,14,12,bars[0],entry_short,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_RECLAIM_THEN_MIDPOINT_CONFIRM",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      if(bars[2].close>or_data.high && bars[1].close>or_data.high-atr*0.05 && bars[0].close<or_data.high)
        {
         double stop=XDF_ShortMRStructuralStop(MathMax(bars[2].high,bars[1].high),atr,entry_short);
         double tp=XDF_ShortMRTarget(or_data,vwap,entry_short,stop,1.05);
         candidate=BuildSignal(-1,"MR_FALSE_BREAK_HOLD_FAIL",22,17,13,15,11,bars[0],entry_short,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_FALSE_BREAK_HOLD_FAIL",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(bars[2].close<or_data.low && bars[1].close<or_data.low+atr*0.05 && bars[0].close>or_data.low)
        {
         double stop=XDF_LongMRStructuralStop(MathMin(bars[2].low,bars[1].low),atr,entry_long);
         double tp=XDF_LongMRTarget(or_data,vwap,entry_long,stop,1.05);
         candidate=BuildSignal(1,"MR_FALSE_BREAK_HOLD_FAIL",22,17,13,15,11,bars[0],entry_long,stop,tp,vwap,0.0);
         XDF_ValidateMRGeometry(candidate,"MR_FALSE_BREAK_HOLD_FAIL",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      if(!best.valid)
         MarkInvalid(best,"no_mr_subtype_match");
      return(best);
     }

   XDFSignal Evaluate(const string symbol,const XDFOpeningRange &or_data,double vwap,double atr)
      {
      return(EvaluateAt(symbol,1,or_data,vwap,atr,SymbolInfoDouble(symbol,SYMBOL_ASK),SymbolInfoDouble(symbol,SYMBOL_BID),SymbolInfoDouble(symbol,SYMBOL_POINT),0.0,0.0,REGIME_MIXED));
      }
  };

#endif
