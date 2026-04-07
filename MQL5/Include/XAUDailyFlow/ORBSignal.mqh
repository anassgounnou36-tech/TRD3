#ifndef XAUDAILYFLOW_ORBSIGNAL_MQH
#define XAUDAILYFLOW_ORBSIGNAL_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFORBSignal
  {
private:
   // Hard cap factor for direct-break stop distance relative to ATR.
   static const double XDF_DIRECT_BREAK_STOP_CAP_ATR_FACTOR;
   // Hard cap factor for direct-break stop distance relative to OR width.
   static const double XDF_DIRECT_BREAK_STOP_CAP_OR_WIDTH_FACTOR;
   // ATR offset factor included in OR-width stop cap computation.
   static const double XDF_DIRECT_BREAK_STOP_CAP_ATR_OFFSET_FACTOR;
   string XDF_LocalRegimeToString(const XDFRegime regime) const
     {
      if(regime==REGIME_TREND_CONTINUATION)
         return("TREND_CONTINUATION");
      if(regime==REGIME_MEAN_REVERSION)
         return("MEAN_REVERSION");
      if(regime==REGIME_MIXED)
         return("MIXED");
      return("NO_TRADE");
     }
   bool XDF_IsORBContinuationSubtype(const string subtype) const
     {
      return(subtype=="ORB_DIRECT_BREAK" ||
             subtype=="ORB_BREAK_PAUSE_CONTINUE" ||
             subtype=="ORB_BREAK_RETEST_HOLD" ||
             subtype=="ORB_TWO_BAR_CONFIRM");
     }
   bool XDF_CloseBeyondEdge(const MqlRates &bar,const bool long_dir,const double edge) const
      {
       return(long_dir ? (bar.close>edge) : (bar.close<edge));
      }
   bool XDF_ValidateORBPostBreakQuality(const string symbol,
                                        const int shift,
                                        const XDFOpeningRange &or_data,
                                        const string subtype,
                                        const XDFRegime regime,
                                        const int direction,
                                        const double atr_pts,
                                        const double spread_pts,
                                        const bool both_sides_violated,
                                        const double stop_pts,
                                        const double or_width_pts,
                                        string &reason_out,
                                        double &confirm_buffer_pts_out,
                                        int &bars_since_break_out,
                                        double &postbreak_quality_score_out) const
     {
      reason_out="";
      confirm_buffer_pts_out=0.0;
      bars_since_break_out=0;
      postbreak_quality_score_out=0.0;
      if(!XDF_IsORBContinuationSubtype(subtype))
         return(true);
      double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      if(point<=0.0 || direction==0 || atr_pts<=0.0)
        {
         reason_out="ORB_POSTBREAK_INVALID_INPUTS";
         return(false);
        }

      MqlRates bars[];
      ArraySetAsSeries(bars,true);
      int copied=CopyRates(symbol,PERIOD_M5,shift,10,bars);
      if(copied<6)
        {
         reason_out="ORB_POSTBREAK_INSUFFICIENT_BARS";
         return(false);
        }

      bool long_dir=(direction>0);
      double edge=(long_dir?or_data.high:or_data.low);
      int first_break_idx=-1;
      for(int i=copied-1; i>=0; --i)
        {
         if(XDF_CloseBeyondEdge(bars[i],long_dir,edge))
           {
            first_break_idx=i;
            break;
           }
        }
      if(first_break_idx<0)
        {
         reason_out=(subtype=="ORB_DIRECT_BREAK"?"ORB_DIRECT_BREAK_NO_CLOSE_CONFIRM":"ORB_POSTBREAK_NO_CLOSE_CONFIRM");
         return(false);
        }
      bars_since_break_out=first_break_idx;

      double confirm_close_pts=(long_dir?(bars[0].close-edge):(edge-bars[0].close))/point;
      double range=(bars[0].high-bars[0].low);
      double body=MathAbs(bars[0].close-bars[0].open);
      double body_ratio=(range>0.0?body/range:0.0);
      double close_loc=(range>0.0?(bars[0].close-bars[0].low)/range:0.5);
      bool close_location_ok=(long_dir?(close_loc>=0.65):(close_loc<=0.35));

      if(subtype=="ORB_DIRECT_BREAK")
        {
         if(regime==REGIME_MIXED)
           {
            reason_out="ORB_POSTBREAK_DIRECT_BREAK_BLOCKED_IN_MIXED";
            return(false);
           }
         if(!XDF_CloseBeyondEdge(bars[0],long_dir,edge))
           {
            reason_out="ORB_DIRECT_BREAK_NO_CLOSE_CONFIRM";
            return(false);
           }
         confirm_buffer_pts_out=MathMax(0.15*atr_pts,1.25*spread_pts);
         if(confirm_close_pts<confirm_buffer_pts_out)
           {
            reason_out="ORB_DIRECT_BREAK_LOW_BUFFER";
            return(false);
           }
         if(both_sides_violated)
           {
            reason_out="ORB_DIRECT_BREAK_BOTH_SIDES_VIOLATED";
            return(false);
           }
         if(bars_since_break_out>3)
           {
            reason_out="ORB_DIRECT_BREAK_LATE_ENTRY";
            return(false);
           }
         double direct_break_stop_cap=MathMin(XDF_DIRECT_BREAK_STOP_CAP_ATR_FACTOR*atr_pts,
                                              XDF_DIRECT_BREAK_STOP_CAP_OR_WIDTH_FACTOR*or_width_pts+XDF_DIRECT_BREAK_STOP_CAP_ATR_OFFSET_FACTOR*atr_pts);
         if(stop_pts>direct_break_stop_cap)
           {
            reason_out="ORB_DIRECT_BREAK_WIDE_INVALIDATION";
            return(false);
           }
         postbreak_quality_score_out=55.0+MathMin(20.0,confirm_close_pts)+MathMin(15.0,3.0-bars_since_break_out*0.5);
         return(true);
        }

      if(subtype=="ORB_BREAK_PAUSE_CONTINUE" && regime==REGIME_MIXED)
        {
         if(both_sides_violated)
           {
            reason_out="ORB_POSTBREAK_BOTH_SIDES_VIOLATED";
            return(false);
           }
         if(bars_since_break_out>4)
           {
            reason_out="ORB_POSTBREAK_LATE_FRAGILITY";
            return(false);
           }
         double reentry_tol_pts=MathMax(0.10*atr_pts,1.0*spread_pts);
         double reentry_tol_price=reentry_tol_pts*point;
         bool path1=(XDF_CloseBeyondEdge(bars[1],long_dir,edge) && XDF_CloseBeyondEdge(bars[0],long_dir,edge));
         bool path2_break=XDF_CloseBeyondEdge(bars[2],long_dir,edge);
         bool path2_retest_ok=(long_dir?(bars[1].low>=edge-reentry_tol_price):(bars[1].high<=edge+reentry_tol_price));
         bool path2_reconfirm=XDF_CloseBeyondEdge(bars[0],long_dir,edge);
         bool path2=(path2_break && path2_retest_ok && path2_reconfirm);
         if(!path1 && !path2)
           {
            reason_out="ORB_POSTBREAK_PAUSE_REENTERED_OR_TOO_DEEP";
            return(false);
           }
         if(!path2_retest_ok && path2_break)
           {
            reason_out="ORB_POSTBREAK_PAUSE_REENTERED_OR_TOO_DEEP";
            return(false);
           }
         confirm_buffer_pts_out=MathMax(0.12*atr_pts,1.25*spread_pts);
         if(confirm_close_pts<confirm_buffer_pts_out)
           {
            reason_out="ORB_POSTBREAK_CLOSE_BUFFER_TOO_SMALL";
            return(false);
           }
         if(body_ratio<0.35 || !close_location_ok)
           {
            reason_out="ORB_POSTBREAK_WICKY_CONFIRM";
            return(false);
           }
          postbreak_quality_score_out=60.0+MathMin(20.0,confirm_close_pts)+MathMin(10.0,body_ratio*20.0)+MathMax(0.0,10.0-bars_since_break_out);
          return(true);
         }

      if(subtype=="ORB_BREAK_RETEST_HOLD")
        {
         if(both_sides_violated)
           {
            reason_out="ORB_POSTBREAK_BOTH_SIDES_VIOLATED";
            return(false);
           }
         if(bars_since_break_out>4)
           {
            reason_out="ORB_POSTBREAK_LATE_FRAGILITY";
            return(false);
           }

         double reentry_tol_pts=MathMax(0.08*atr_pts,1.00*spread_pts);
         double retest_touch_tol_pts=MathMax(0.06*atr_pts,0.80*spread_pts);
         double reentry_tol_price=reentry_tol_pts*point;
         double retest_touch_tol_price=retest_touch_tol_pts*point;

         bool saw_retest_touch=false;
         bool saw_shallow_touch_without_hold=false;
         bool saw_deep_reentry=false;
         int retest_idx=-1;
         int closes_beyond_after_break=0;
         int post_break_end=MathMin(first_break_idx-1,copied-1);
         for(int i=post_break_end; i>=0; --i)
           {
            bool close_beyond=XDF_CloseBeyondEdge(bars[i],long_dir,edge);
            if(close_beyond)
               closes_beyond_after_break++;

            bool touch_near_edge=(long_dir?(bars[i].low<=edge+retest_touch_tol_price):(bars[i].high>=edge-retest_touch_tol_price));
            bool deep_reentry=(long_dir?(bars[i].low<edge-reentry_tol_price):(bars[i].high>edge+reentry_tol_price));
            if(deep_reentry)
               saw_deep_reentry=true;
            if(touch_near_edge)
              {
               saw_retest_touch=true;
               retest_idx=i;
               if(!close_beyond)
                  saw_shallow_touch_without_hold=true;
              }
           }

         if(!saw_retest_touch || retest_idx<0)
           {
            reason_out="ORB_POSTBREAK_RETEST_NO_ACCEPTANCE";
            return(false);
           }
         if(saw_deep_reentry || saw_shallow_touch_without_hold)
           {
            reason_out="ORB_POSTBREAK_PAUSE_REENTERED_OR_TOO_DEEP";
            return(false);
           }
         if(closes_beyond_after_break<2)
           {
            reason_out="ORB_POSTBREAK_RETEST_UNSTABLE_CONTINUATION";
            return(false);
           }

         int closes_after_retest=0;
         for(int i=retest_idx-1; i>=0; --i)
           {
            if(XDF_CloseBeyondEdge(bars[i],long_dir,edge))
               closes_after_retest++;
           }
         if(closes_after_retest<1)
           {
            reason_out="ORB_POSTBREAK_RETEST_NO_ACCEPTANCE";
            return(false);
           }

         confirm_buffer_pts_out=MathMax(0.14*atr_pts,1.50*spread_pts);
         if(confirm_close_pts<confirm_buffer_pts_out)
           {
            reason_out="ORB_POSTBREAK_CLOSE_BUFFER_TOO_SMALL";
            return(false);
           }
         if(body_ratio<0.45 || !close_location_ok)
           {
            reason_out="ORB_POSTBREAK_WICKY_CONFIRM";
            return(false);
           }
         postbreak_quality_score_out=62.0+MathMin(18.0,confirm_close_pts)+MathMin(12.0,body_ratio*20.0)+MathMax(0.0,10.0-bars_since_break_out);
         return(true);
        }

      confirm_buffer_pts_out=MathMax(0.10*atr_pts,spread_pts);
      postbreak_quality_score_out=50.0+MathMin(20.0,confirm_close_pts)+MathMin(10.0,body_ratio*20.0)+MathMax(0.0,10.0-bars_since_break_out);
      return(true);
     }
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
      s.postbreak_quality_score=0.0;
      s.postbreak_quality_pass=false;
      s.postbreak_reject_reason="";
      s.confirm_buffer_pts=0.0;
      s.bars_since_initial_break=0;
     }
   bool XDF_ValidateORBGeometry(XDFSignal &s,const string subtype,const XDFRegime regime,const double point,const double atr,const double or_width,const double spread_points,const double slip_points)
      {
       if(!s.valid || point<=0.0 || atr<=0.0 || or_width<=0.0)
         {
          s.valid=false;
          s.reason_invalid=StringFormat("ORB_GEOMETRY_INVALID_INPUTS source_geom_regime=%s",XDF_LocalRegimeToString(regime));
          return(false);
         }

       XDF_SetGeometryMetrics(s,point,atr,or_width,spread_points,slip_points);
       XDFGeometryMetrics metrics;
       string reason;
       bool pass=XDF_PassesGeometryPolicy(SETUP_ORB_CONTINUATION,subtype,regime,s.stop_points,s.target_points,s.spread_points,s.slip_points,s.atr_points,s.or_width_points,metrics,reason);
       s.gross_rr=metrics.gross_rr;
       s.net_target_points=metrics.net_target_points;
       s.net_rr=metrics.net_rr;
       s.reason=StringFormat("%s source_geom_regime=%s",subtype,XDF_LocalRegimeToString(regime));
       if(!pass)
         {
          s.valid=false;
          s.reason_invalid=StringFormat("%s source_geom_regime=%s",reason,XDF_LocalRegimeToString(regime));
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
      if(candidate.net_rr>=current_best.net_rr+0.10)
         return(true);
      if(candidate.net_rr<=current_best.net_rr-0.10)
         return(false);
      if(MathAbs(candidate.net_rr-current_best.net_rr)<0.10)
        {
         if(candidate.postbreak_quality_score>=current_best.postbreak_quality_score+3.0)
            return(true);
         if(candidate.postbreak_quality_score+3.0<=current_best.postbreak_quality_score)
            return(false);
        }
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
      s.postbreak_quality_score=0.0;
      s.postbreak_quality_pass=false;
      s.postbreak_reject_reason="";
      s.confirm_buffer_pts=0.0;
      s.bars_since_initial_break=0;
      return(s);
     }

   void MarkInvalid(XDFSignal &s,const string reason)
     {
      s.valid=false;
      s.reason_invalid=reason;
      if(s.subtype=="")
         s.subtype="NONE";
     }
   void TrackRejectedPostBreakCandidate(const XDFSignal &candidate,XDFSignal &best_rejected,bool &has_rejected) const
     {
      if(candidate.postbreak_reject_reason=="")
         return;
      if(!has_rejected)
        {
         best_rejected=candidate;
         has_rejected=true;
         return;
        }
      if(candidate.raw_structure_quality>best_rejected.raw_structure_quality)
        {
         best_rejected=candidate;
         return;
        }
      if(candidate.raw_structure_quality<best_rejected.raw_structure_quality)
         return;
      if(candidate.net_rr>best_rejected.net_rr+0.01)
         best_rejected=candidate;
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
                         const double expected_slippage_points,
                         const XDFRegime regime,
                         const bool both_sides_violated)
     {
      XDFSignal best;
      XDFSignal best_rejected_postbreak;
      bool has_rejected_postbreak=false;
      ZeroMemory(best);
      ZeroMemory(best_rejected_postbreak);
      best.family=SETUP_ORB_CONTINUATION;
      best.subtype="NONE";
      if(!or_data.valid || atr<=0.0 || shift<1)
        {
         MarkInvalid(best,"invalid_or_or_atr_or_shift");
         return(best);
        }

      MqlRates bars[];
      ArraySetAsSeries(bars,true);
      if(CopyRates(symbol,PERIOD_M5,shift,8,bars)<5)
        {
         MarkInvalid(best,"insufficient_closed_bars");
         return(best);
        }

      MqlRates b0=bars[0];
      MqlRates b1=bars[1];
      MqlRates b2=bars[2];
      MqlRates b3=bars[3];
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
             if(XDF_ValidateORBGeometry(candidate,"ORB_DIRECT_BREAK",regime,point,atr,or_width,spread_points,expected_slippage_points))
               {
                string postbreak_reason;
                double confirm_buffer_pts=0.0;
                int bars_since_break=0;
                double postbreak_score=0.0;
                bool postbreak_ok=XDF_ValidateORBPostBreakQuality(symbol,shift,or_data,candidate.subtype,regime,candidate.direction,candidate.atr_points,candidate.spread_points,both_sides_violated,candidate.stop_points,candidate.or_width_points,postbreak_reason,confirm_buffer_pts,bars_since_break,postbreak_score);
                candidate.confirm_buffer_pts=confirm_buffer_pts;
                candidate.bars_since_initial_break=bars_since_break;
                candidate.postbreak_quality_score=postbreak_score;
                candidate.postbreak_quality_pass=postbreak_ok;
                if(!postbreak_ok)
                  {
                   candidate.postbreak_reject_reason=postbreak_reason;
                   MarkInvalid(candidate,postbreak_reason);
                   TrackRejectedPostBreakCandidate(candidate,best_rejected_postbreak,has_rejected_postbreak);
                  }
                }
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
             if(XDF_ValidateORBGeometry(candidate,"ORB_DIRECT_BREAK",regime,point,atr,or_width,spread_points,expected_slippage_points))
               {
                string postbreak_reason;
                double confirm_buffer_pts=0.0;
                int bars_since_break=0;
                double postbreak_score=0.0;
                bool postbreak_ok=XDF_ValidateORBPostBreakQuality(symbol,shift,or_data,candidate.subtype,regime,candidate.direction,candidate.atr_points,candidate.spread_points,both_sides_violated,candidate.stop_points,candidate.or_width_points,postbreak_reason,confirm_buffer_pts,bars_since_break,postbreak_score);
                candidate.confirm_buffer_pts=confirm_buffer_pts;
                candidate.bars_since_initial_break=bars_since_break;
                candidate.postbreak_quality_score=postbreak_score;
                candidate.postbreak_quality_pass=postbreak_ok;
                if(!postbreak_ok)
                  {
                   candidate.postbreak_reject_reason=postbreak_reason;
                   MarkInvalid(candidate,postbreak_reason);
                   TrackRejectedPostBreakCandidate(candidate,best_rejected_postbreak,has_rejected_postbreak);
                  }
                }
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
         XDF_ValidateORBGeometry(candidate,"ORB_BREAK_RETEST_HOLD",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(candidate.valid)
           {
            string postbreak_reason;
            double confirm_buffer_pts=0.0;
            int bars_since_break=0;
            double postbreak_score=0.0;
            bool postbreak_ok=XDF_ValidateORBPostBreakQuality(symbol,shift,or_data,candidate.subtype,regime,candidate.direction,candidate.atr_points,candidate.spread_points,both_sides_violated,candidate.stop_points,candidate.or_width_points,postbreak_reason,confirm_buffer_pts,bars_since_break,postbreak_score);
            candidate.confirm_buffer_pts=confirm_buffer_pts;
            candidate.bars_since_initial_break=bars_since_break;
            candidate.postbreak_quality_score=postbreak_score;
            candidate.postbreak_quality_pass=postbreak_ok;
            if(!postbreak_ok)
              {
               candidate.postbreak_reject_reason=postbreak_reason;
               MarkInvalid(candidate,postbreak_reason);
               TrackRejectedPostBreakCandidate(candidate,best_rejected_postbreak,has_rejected_postbreak);
              }
           }
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
         XDF_ValidateORBGeometry(candidate,"ORB_BREAK_RETEST_HOLD",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(candidate.valid)
           {
            string postbreak_reason;
            double confirm_buffer_pts=0.0;
            int bars_since_break=0;
            double postbreak_score=0.0;
            bool postbreak_ok=XDF_ValidateORBPostBreakQuality(symbol,shift,or_data,candidate.subtype,regime,candidate.direction,candidate.atr_points,candidate.spread_points,both_sides_violated,candidate.stop_points,candidate.or_width_points,postbreak_reason,confirm_buffer_pts,bars_since_break,postbreak_score);
            candidate.confirm_buffer_pts=confirm_buffer_pts;
            candidate.bars_since_initial_break=bars_since_break;
            candidate.postbreak_quality_score=postbreak_score;
            candidate.postbreak_quality_pass=postbreak_ok;
            if(!postbreak_ok)
              {
               candidate.postbreak_reject_reason=postbreak_reason;
               MarkInvalid(candidate,postbreak_reason);
               TrackRejectedPostBreakCandidate(candidate,best_rejected_postbreak,has_rejected_postbreak);
              }
           }
         if(IsBetter(candidate,best))
            best=candidate;
        }

      if(ema_long_ok && b1.close>=or_data.high-atr*0.14 && b0.close>or_data.high && b0.close>b1.close)
        {
         double structure_low=MathMin(b0.low,b1.low);
         double stop=XDF_LongORBStructuralStop(structure_low,atr,or_data,entry_long,min_stop_distance);
         double tp=XDF_LongTargetFromStructure(or_data,b0,vwap,entry_long,stop,1.05);
         candidate=BuildSignal(1,"ORB_TWO_BAR_CONFIRM",23,8,21,12,(ema_long_ok?14:8),b0,entry_long,stop,tp,vwap,0.0);
         XDF_ValidateORBGeometry(candidate,"ORB_TWO_BAR_CONFIRM",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(candidate.valid)
           {
            string postbreak_reason;
            double confirm_buffer_pts=0.0;
            int bars_since_break=0;
            double postbreak_score=0.0;
            bool postbreak_ok=XDF_ValidateORBPostBreakQuality(symbol,shift,or_data,candidate.subtype,regime,candidate.direction,candidate.atr_points,candidate.spread_points,both_sides_violated,candidate.stop_points,candidate.or_width_points,postbreak_reason,confirm_buffer_pts,bars_since_break,postbreak_score);
            candidate.confirm_buffer_pts=confirm_buffer_pts;
            candidate.bars_since_initial_break=bars_since_break;
            candidate.postbreak_quality_score=postbreak_score;
            candidate.postbreak_quality_pass=postbreak_ok;
            if(!postbreak_ok)
              {
               candidate.postbreak_reject_reason=postbreak_reason;
               MarkInvalid(candidate,postbreak_reason);
               TrackRejectedPostBreakCandidate(candidate,best_rejected_postbreak,has_rejected_postbreak);
              }
           }
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(ema_short_ok && b1.close<=or_data.low+atr*0.14 && b0.close<or_data.low && b0.close<b1.close)
        {
         double structure_high=MathMax(b0.high,b1.high);
         double stop=XDF_ShortORBStructuralStop(structure_high,atr,or_data,entry_short,min_stop_distance);
         double tp=XDF_ShortTargetFromStructure(or_data,b0,vwap,entry_short,stop,1.05);
         candidate=BuildSignal(-1,"ORB_TWO_BAR_CONFIRM",23,8,21,12,(ema_short_ok?14:8),b0,entry_short,stop,tp,vwap,0.0);
         XDF_ValidateORBGeometry(candidate,"ORB_TWO_BAR_CONFIRM",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(candidate.valid)
           {
            string postbreak_reason;
            double confirm_buffer_pts=0.0;
            int bars_since_break=0;
            double postbreak_score=0.0;
            bool postbreak_ok=XDF_ValidateORBPostBreakQuality(symbol,shift,or_data,candidate.subtype,regime,candidate.direction,candidate.atr_points,candidate.spread_points,both_sides_violated,candidate.stop_points,candidate.or_width_points,postbreak_reason,confirm_buffer_pts,bars_since_break,postbreak_score);
            candidate.confirm_buffer_pts=confirm_buffer_pts;
            candidate.bars_since_initial_break=bars_since_break;
            candidate.postbreak_quality_score=postbreak_score;
            candidate.postbreak_quality_pass=postbreak_ok;
            if(!postbreak_ok)
              {
               candidate.postbreak_reject_reason=postbreak_reason;
               MarkInvalid(candidate,postbreak_reason);
               TrackRejectedPostBreakCandidate(candidate,best_rejected_postbreak,has_rejected_postbreak);
              }
           }
         if(IsBetter(candidate,best))
            best=candidate;
        }

      if(ema_long_ok && b2.close>or_data.high && b1.low>or_data.high-atr*0.20 && b1.close>or_data.high-atr*0.08 && b0.close>or_data.high)
        {
         double structure_low=MathMin(MathMin(b0.low,b1.low),b2.low);
         double stop=XDF_LongORBStructuralStop(structure_low,atr,or_data,entry_long,min_stop_distance);
         double tp=XDF_LongTargetFromStructure(or_data,b0,vwap,entry_long,stop,1.10);
         candidate=BuildSignal(1,"ORB_BREAK_PAUSE_CONTINUE",22,12,16,20,(ema_long_ok?13:8),b0,entry_long,stop,tp,vwap,0.0);
         XDF_ValidateORBGeometry(candidate,"ORB_BREAK_PAUSE_CONTINUE",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(candidate.valid)
           {
            string postbreak_reason;
            double confirm_buffer_pts=0.0;
            int bars_since_break=0;
            double postbreak_score=0.0;
            bool postbreak_ok=XDF_ValidateORBPostBreakQuality(symbol,shift,or_data,candidate.subtype,regime,candidate.direction,candidate.atr_points,candidate.spread_points,both_sides_violated,candidate.stop_points,candidate.or_width_points,postbreak_reason,confirm_buffer_pts,bars_since_break,postbreak_score);
            candidate.confirm_buffer_pts=confirm_buffer_pts;
            candidate.bars_since_initial_break=bars_since_break;
            candidate.postbreak_quality_score=postbreak_score;
            candidate.postbreak_quality_pass=postbreak_ok;
            if(!postbreak_ok)
              {
               candidate.postbreak_reject_reason=postbreak_reason;
               MarkInvalid(candidate,postbreak_reason);
               TrackRejectedPostBreakCandidate(candidate,best_rejected_postbreak,has_rejected_postbreak);
              }
           }
         if(IsBetter(candidate,best))
            best=candidate;
        }
      if(ema_short_ok && b2.close<or_data.low && b1.high<or_data.low+atr*0.20 && b1.close<or_data.low+atr*0.08 && b0.close<or_data.low)
        {
         double structure_high=MathMax(MathMax(b0.high,b1.high),b2.high);
         double stop=XDF_ShortORBStructuralStop(structure_high,atr,or_data,entry_short,min_stop_distance);
         double tp=XDF_ShortTargetFromStructure(or_data,b0,vwap,entry_short,stop,1.10);
         candidate=BuildSignal(-1,"ORB_BREAK_PAUSE_CONTINUE",22,12,16,20,(ema_short_ok?13:8),b0,entry_short,stop,tp,vwap,0.0);
         XDF_ValidateORBGeometry(candidate,"ORB_BREAK_PAUSE_CONTINUE",regime,point,atr,or_width,spread_points,expected_slippage_points);
         if(candidate.valid)
           {
            string postbreak_reason;
            double confirm_buffer_pts=0.0;
            int bars_since_break=0;
            double postbreak_score=0.0;
            bool postbreak_ok=XDF_ValidateORBPostBreakQuality(symbol,shift,or_data,candidate.subtype,regime,candidate.direction,candidate.atr_points,candidate.spread_points,both_sides_violated,candidate.stop_points,candidate.or_width_points,postbreak_reason,confirm_buffer_pts,bars_since_break,postbreak_score);
            candidate.confirm_buffer_pts=confirm_buffer_pts;
            candidate.bars_since_initial_break=bars_since_break;
            candidate.postbreak_quality_score=postbreak_score;
            candidate.postbreak_quality_pass=postbreak_ok;
            if(!postbreak_ok)
              {
               candidate.postbreak_reject_reason=postbreak_reason;
               MarkInvalid(candidate,postbreak_reason);
               TrackRejectedPostBreakCandidate(candidate,best_rejected_postbreak,has_rejected_postbreak);
              }
           }
         if(IsBetter(candidate,best))
            best=candidate;
        }

      if(!best.valid && has_rejected_postbreak)
         best=best_rejected_postbreak;
      if(!best.valid && best.reason_invalid=="")
         MarkInvalid(best,"no_orb_subtype_match");
      return(best);
     }

    XDFSignal Evaluate(const string symbol,const XDFOpeningRange &or_data,double vwap,double atr,bool ema_long_ok,bool ema_short_ok,double min_stop_distance)
      {
       return(EvaluateAt(symbol,1,or_data,vwap,atr,ema_long_ok,ema_short_ok,min_stop_distance,SymbolInfoDouble(symbol,SYMBOL_ASK),SymbolInfoDouble(symbol,SYMBOL_BID),SymbolInfoDouble(symbol,SYMBOL_POINT),0.0,0.0,REGIME_MIXED,false));
      }
  };

const double XDFORBSignal::XDF_DIRECT_BREAK_STOP_CAP_ATR_FACTOR=0.80;
const double XDFORBSignal::XDF_DIRECT_BREAK_STOP_CAP_OR_WIDTH_FACTOR=0.60;
const double XDFORBSignal::XDF_DIRECT_BREAK_STOP_CAP_ATR_OFFSET_FACTOR=0.10;

#endif
