#ifndef XAUDAILYFLOW_ORBSIGNAL_MQH
#define XAUDAILYFLOW_ORBSIGNAL_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFORBSignal
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
   bool XDF_ValidateORBGeometry(XDFSignal &s,const string subtype,const double point,const double atr,const double or_width,const double spread_points,const double slip_points)
     {
      if(!s.valid || point<=0.0 || atr<=0.0 || or_width<=0.0)
        {
         s.valid=false;
         s.reason_invalid="ORB_GEOMETRY_INVALID_INPUTS";
         return(false);
        }

      XDF_SetGeometryMetrics(s,point,atr,or_width,spread_points,slip_points);

      double stop_floor=MathMax(0.22*s.atr_points,1.20*s.spread_points+2.0*s.slip_points);
      if(s.stop_points<stop_floor)
        {
         s.valid=false;
         s.reason_invalid="ORB_GEOMETRY_STOP_TOO_TIGHT";
         return(false);
        }

      double stop_cap=MathMin(0.95*s.atr_points,0.75*s.or_width_points+0.10*s.atr_points);
      if(s.stop_points>stop_cap)
        {
         s.valid=false;
         s.reason_invalid="ORB_GEOMETRY_STOP_TOO_WIDE";
         return(false);
        }

      if(s.target_points<=s.stop_points || s.net_target_points<=0.0)
        {
         s.valid=false;
         s.reason_invalid="ORB_GEOMETRY_COST_THIN";
         return(false);
        }

      if(s.net_rr<0.95)
        {
         s.valid=false;
         s.reason_invalid="ORB_GEOMETRY_NET_R_TOO_LOW";
         return(false);
        }

      if((subtype=="ORB_DIRECT_BREAK" || subtype=="ORB_BREAK_PAUSE_CONTINUE") && s.net_rr<1.00)
        {
         s.valid=false;
         s.reason_invalid="ORB_GEOMETRY_NET_R_TOO_LOW";
         return(false);
        }

      return(true);
     }
   double XDF_LongORBStructuralStop(const double structure_low,const double atr,const XDFOpeningRange &or_data,const double entry,const double min_stop_distance)
     {
      double stop=structure_low-atr*0.08;
      double clamp_min=or_data.high-atr*0.15;
      if(stop<clamp_min)
         stop=clamp_min;
      if(entry-stop<min_stop_distance)
         stop=entry-min_stop_distance;
      return(stop);
     }
   double XDF_ShortORBStructuralStop(const double structure_high,const double atr,const XDFOpeningRange &or_data,const double entry,const double min_stop_distance)
     {
      double stop=structure_high+atr*0.08;
      double clamp_max=or_data.low+atr*0.15;
      if(stop>clamp_max)
         stop=clamp_max;
      if(stop-entry<min_stop_distance)
         stop=entry+min_stop_distance;
      return(stop);
     }
   double XDF_LongTargetFromStructure(const XDFOpeningRange &or_data,const MqlRates &b0,const double vwap,const double entry,const double stop,const double min_rr)
     {
      double risk=MathAbs(entry-stop);
      if(risk<=0.0)
         return(entry);
      double required=entry+risk*min_rr;
      double structural=MathMax(MathMax(or_data.high+or_data.width*0.60,b0.high+or_data.width*0.35),vwap+or_data.width*0.30);
      return(MathMax(required,structural));
     }
   double XDF_ShortTargetFromStructure(const XDFOpeningRange &or_data,const MqlRates &b0,const double vwap,const double entry,const double stop,const double min_rr)
     {
      double risk=MathAbs(entry-stop);
      if(risk<=0.0)
         return(entry);
      double required=entry-risk*min_rr;
      double structural=MathMin(MathMin(or_data.low-or_data.width*0.60,b0.low-or_data.width*0.35),vwap-or_data.width*0.30);
      return(MathMin(required,structural));
     }
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
      if(candidate.net_rr>current_best.net_rr+0.10)
         return(true);
      if(candidate.net_rr+0.10<current_best.net_rr)
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
                        double entry_short,
                        const double point,
                        const double spread_points,
                        const double expected_slippage_points)
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
      double or_width=MathMax(or_data.width,atr*0.25);
      XDFSignal candidate;

      if(ema_long_ok && b0.close>or_data.high && b0.close>vwap)
        {
         double ext=(b0.close-or_data.high);
         if(ext<ext_limit*1.1)
           {
            double stop=XDF_LongORBStructuralStop(MathMin(b0.low,b1.low),atr,or_data,entry_long,min_stop_distance);
            double tp=XDF_LongTargetFromStructure(or_data,b0,vwap,entry_long,stop,1.00);
            candidate=BuildSignal(1,"ORB_DIRECT_BREAK",26,0,18,12,(ema_long_ok?15:8),b0,entry_long,stop,tp,vwap,ExtensionPenalty(ext,atr));
            XDF_ValidateORBGeometry(candidate,"ORB_DIRECT_BREAK",point,atr,or_width,spread_points,expected_slippage_points);
            if(IsBetter(candidate,best))
               best=candidate;
           }
        }
      if(ema_short_ok && b0.close<or_data.low && b0.close<vwap)
        {
         double ext=(or_data.low-b0.close);
         if(ext<ext_limit*1.1)
           {
            double stop=XDF_ShortORBStructuralStop(MathMax(b0.high,b1.high),atr,or_data,entry_short,min_stop_distance);
            double tp=XDF_ShortTargetFromStructure(or_data,b0,vwap,entry_short,stop,1.00);
            candidate=BuildSignal(-1,"ORB_DIRECT_BREAK",26,0,18,12,(ema_short_ok?15:8),b0,entry_short,stop,tp,vwap,ExtensionPenalty(ext,atr));
            XDF_ValidateORBGeometry(candidate,"ORB_DIRECT_BREAK",point,atr,or_width,spread_points,expected_slippage_points);
            if(IsBetter(candidate,best))
               best=candidate;
           }
        }

      if(ema_long_ok && (b2.close>or_data.high || b1.close>or_data.high) &&
         ((b1.low>=or_data.high-atr*0.24 && b0.close>or_data.high) || (b0.low>=or_data.high-atr*0.24 && b0.close>or_data.high)))
        {
         double structure_low=MathMin(MathMin(b0.low,b1.low),or_data.high-atr*0.10);
         double stop=XDF_LongORBStructuralStop(structure_low,atr,or_data,entry_long,min_stop_distance);
         double tp=XDF_LongTargetFromStructure(or_data,b0,vwap,entry_long,stop,1.10);
         candidate=BuildSignal(1,"ORB_BREAK_RETEST_HOLD",25,19,15,16,(ema_long_ok?14:8),b0,entry_long,stop,tp,vwap,0.0);
         XDF_ValidateORBGeometry(candidate,"ORB_BREAK_RETEST_HOLD",point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(ema_short_ok && (b2.close<or_data.low || b1.close<or_data.low) &&
         ((b1.high<=or_data.low+atr*0.24 && b0.close<or_data.low) || (b0.high<=or_data.low+atr*0.24 && b0.close<or_data.low)))
        {
         double structure_high=MathMax(MathMax(b0.high,b1.high),or_data.low+atr*0.10);
         double stop=XDF_ShortORBStructuralStop(structure_high,atr,or_data,entry_short,min_stop_distance);
         double tp=XDF_ShortTargetFromStructure(or_data,b0,vwap,entry_short,stop,1.10);
         candidate=BuildSignal(-1,"ORB_BREAK_RETEST_HOLD",25,19,15,16,(ema_short_ok?14:8),b0,entry_short,stop,tp,vwap,0.0);
         XDF_ValidateORBGeometry(candidate,"ORB_BREAK_RETEST_HOLD",point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      if(ema_long_ok && b1.close>=or_data.high-atr*0.14 && b0.close>or_data.high && b0.close>b1.close)
        {
         double structure_low=MathMin(b0.low,b1.low);
         double stop=XDF_LongORBStructuralStop(structure_low,atr,or_data,entry_long,min_stop_distance);
         double tp=XDF_LongTargetFromStructure(or_data,b0,vwap,entry_long,stop,1.05);
         candidate=BuildSignal(1,"ORB_TWO_BAR_CONFIRM",23,8,21,12,(ema_long_ok?14:8),b0,entry_long,stop,tp,vwap,0.0);
         XDF_ValidateORBGeometry(candidate,"ORB_TWO_BAR_CONFIRM",point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(ema_short_ok && b1.close<=or_data.low+atr*0.14 && b0.close<or_data.low && b0.close<b1.close)
        {
         double structure_high=MathMax(b0.high,b1.high);
         double stop=XDF_ShortORBStructuralStop(structure_high,atr,or_data,entry_short,min_stop_distance);
         double tp=XDF_ShortTargetFromStructure(or_data,b0,vwap,entry_short,stop,1.05);
         candidate=BuildSignal(-1,"ORB_TWO_BAR_CONFIRM",23,8,21,12,(ema_short_ok?14:8),b0,entry_short,stop,tp,vwap,0.0);
         XDF_ValidateORBGeometry(candidate,"ORB_TWO_BAR_CONFIRM",point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      if(ema_long_ok && b2.close>or_data.high && b1.low>or_data.high-atr*0.20 && b1.close>or_data.high-atr*0.08 && b0.close>or_data.high)
        {
         double structure_low=MathMin(MathMin(b0.low,b1.low),b2.low);
         double stop=XDF_LongORBStructuralStop(structure_low,atr,or_data,entry_long,min_stop_distance);
         double tp=XDF_LongTargetFromStructure(or_data,b0,vwap,entry_long,stop,1.10);
         candidate=BuildSignal(1,"ORB_BREAK_PAUSE_CONTINUE",22,12,16,20,(ema_long_ok?13:8),b0,entry_long,stop,tp,vwap,0.0);
         XDF_ValidateORBGeometry(candidate,"ORB_BREAK_PAUSE_CONTINUE",point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(ema_short_ok && b2.close<or_data.low && b1.high<or_data.low+atr*0.20 && b1.close<or_data.low+atr*0.08 && b0.close<or_data.low)
        {
         double structure_high=MathMax(MathMax(b0.high,b1.high),b2.high);
         double stop=XDF_ShortORBStructuralStop(structure_high,atr,or_data,entry_short,min_stop_distance);
         double tp=XDF_ShortTargetFromStructure(or_data,b0,vwap,entry_short,stop,1.10);
         candidate=BuildSignal(-1,"ORB_BREAK_PAUSE_CONTINUE",22,12,16,20,(ema_short_ok?13:8),b0,entry_short,stop,tp,vwap,0.0);
         XDF_ValidateORBGeometry(candidate,"ORB_BREAK_PAUSE_CONTINUE",point,atr,or_width,spread_points,expected_slippage_points);
         if(IsBetter(candidate,best))
            best=candidate;
        }

      if(!best.valid)
         MarkInvalid(best,"no_orb_subtype_match");
      return(best);
     }

   XDFSignal Evaluate(const string symbol,const XDFOpeningRange &or_data,double vwap,double atr,bool ema_long_ok,bool ema_short_ok,double min_stop_distance)
     {
      return(EvaluateAt(symbol,1,or_data,vwap,atr,ema_long_ok,ema_short_ok,min_stop_distance,SymbolInfoDouble(symbol,SYMBOL_ASK),SymbolInfoDouble(symbol,SYMBOL_BID),SymbolInfoDouble(symbol,SYMBOL_POINT),0.0,0.0));
     }
  };

#endif
