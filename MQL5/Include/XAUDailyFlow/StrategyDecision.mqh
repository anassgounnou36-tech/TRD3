#ifndef XAUDAILYFLOW_STRATEGYDECISION_MQH
#define XAUDAILYFLOW_STRATEGYDECISION_MQH

#include <XAUDailyFlow/Types.mqh>
#include <XAUDailyFlow/RegimeEngine.mqh>
#include <XAUDailyFlow/ORBSignal.mqh>
#include <XAUDailyFlow/MeanReversionSignal.mqh>
#include <XAUDailyFlow/SetupScorer.mqh>
#include <XAUDailyFlow/NoTradeFilter.mqh>

class XDFStrategyDecisionEngine
  {
private:
   XDFRegimeEngine m_regime;
   XDFORBSignal m_orb;
   XDFMeanReversionSignal m_mr;
   XDFSetupScorer m_scorer;
   // v1.5.4 correction: exceptional counter-trend MR must be elite-only in trend continuation.
   static const int XDF_MR_EXCEPTION_MIN_SCORE;
   // v1.5.4 correction: if ORB is at least this strong, MR override is disallowed.
   static const int XDF_ORB_ACCEPTABLE_QUALITY_SCORE;
   // v1.5.4 correction: exceptional MR needs a clear edge to beat continuation ORB.
   static const int XDF_MR_OVERRIDE_MARGIN_OVER_ORB;
   // v1.5.4 correction: stronger M15 slope means continuation bias should dominate.
   static const double XDF_M15_STRONG_CONTINUATION_SLOPE;
   bool HasGenuineReclaim(const XDFSignal &mr) const
     {
      return(mr.reclaim_window_quality>=12 &&
             mr.level_hold_quality>=12 &&
             mr.confirmation_quality>=16 &&
             mr.trigger_body_ratio>=0.45);
     }
   bool PassesPayoffGate(const XDFSignal &signal,const XDFDecisionContext &ctx,double &stop_dist_pts,double &target_dist_pts,double &spread_pts,double &expected_slip_pts,string &gate_detail) const
      {
      stop_dist_pts=0.0;
      target_dist_pts=0.0;
      spread_pts=ctx.spread_points;
      expected_slip_pts=ctx.expected_slippage_points;
      gate_detail="";
      if(!signal.valid || ctx.point<=0.0)
         return(false);
      stop_dist_pts=signal.stop_distance/ctx.point;
      target_dist_pts=signal.target_distance/ctx.point;
      if(stop_dist_pts<=0.0 || target_dist_pts<=0.0)
        {
         gate_detail="invalid_distance_points";
         return(false);
        }
      double min_target=(signal.family==SETUP_ORB_CONTINUATION?
                         MathMax(stop_dist_pts*0.75,spread_pts*2.0+expected_slip_pts):
                         MathMax(stop_dist_pts*1.00,spread_pts*2.5+expected_slip_pts));
      double min_net=(signal.family==SETUP_ORB_CONTINUATION?spread_pts*1.0:spread_pts*1.25);
      double net_target=target_dist_pts-spread_pts-expected_slip_pts;
      bool pass=(target_dist_pts>=min_target && net_target>=min_net);
      if(!pass)
        {
         double rr=(stop_dist_pts>0.0?target_dist_pts/stop_dist_pts:0.0);
         gate_detail=StringFormat("build=v1.5.5-risk-geometry-fix-1 family=%d subtype=%s rr=%.2f stopPts=%.1f targetPts=%.1f spreadPts=%.1f slipPts=%.1f blocker=BLOCKER_PAYOFF minTarget=%.1f net=%.1f minNet=%.1f",
                                  (int)signal.family,signal.subtype,rr,stop_dist_pts,target_dist_pts,spread_pts,expected_slip_pts,min_target,net_target,min_net);
        }
      return(pass);
      }
   bool PassesExceptionalMRPayoff(const double stop_dist_pts,const double target_dist_pts,const double spread_pts,const double expected_slip_pts) const
     {
      if(stop_dist_pts<=0.0 || target_dist_pts<=0.0)
         return(false);
      double min_target=MathMax(stop_dist_pts*1.10,spread_pts*3.0+expected_slip_pts);
      double min_net=spread_pts*1.5;
      double net_target=target_dist_pts-spread_pts-expected_slip_pts;
      return(target_dist_pts>=min_target && net_target>=min_net);
     }
   bool IsExceptionalMROverrideAllowed(const XDFRegime regime,const XDFDecisionContext &ctx,const XDFSignal &mr_signal,const int mr_score_final,const XDFSignal &orb_signal,const int orb_score_raw,const bool orb_payoff_ok,const bool mr_payoff_ok,const double mr_stop_pts,const double mr_target_pts,const double mr_spread_pts,const double mr_slip_pts,string &reason) const
      {
      reason="";
      if(regime!=REGIME_TREND_CONTINUATION)
        {
         reason="not_trend_continuation";
         return(false);
        }
      if(!mr_signal.valid || !mr_payoff_ok)
        {
         reason="mr_invalid_or_payoff_fail";
         return(false);
        }
      if(!XDF_IsExceptionalMRSubtype(mr_signal.subtype))
        {
         reason="mr_subtype_not_exceptional";
         return(false);
        }
      if(XDF_IsRestrictedMRSubtype(mr_signal.subtype))
        {
         reason="mr_restricted_subtype";
         return(false);
        }
      if(mr_score_final<XDF_MR_EXCEPTION_MIN_SCORE)
        {
         reason=StringFormat("mr_score_final_%d_below_%d",mr_score_final,XDF_MR_EXCEPTION_MIN_SCORE);
         return(false);
        }
      if(!HasGenuineReclaim(mr_signal))
        {
         reason="mr_reclaim_not_genuine";
         return(false);
        }
      bool orb_acceptable_quality=(orb_signal.valid && orb_payoff_ok && orb_score_raw>=XDF_ORB_ACCEPTABLE_QUALITY_SCORE);
      if(orb_acceptable_quality)
        {
         reason="orb_valid_at_acceptable_quality";
         return(false);
        }
      if(ctx.m15.slope_strength>=XDF_M15_STRONG_CONTINUATION_SLOPE)
        {
         reason="m15_continuation_too_strong";
         return(false);
        }
      if(!PassesExceptionalMRPayoff(mr_stop_pts,mr_target_pts,mr_spread_pts,mr_slip_pts))
        {
         reason="mr_exceptional_payoff_fail";
         return(false);
        }
      reason="EXCEPTIONAL_COUNTERTREND_RECLAIM";
      return(true);
     }
public:
   void EvaluateSignals(const string symbol,const int shift,const XDFOpeningRange &or_data,double vwap,double atr,bool ema_long_ok,bool ema_short_ok,double min_stop_distance,double entry_long,double entry_short,const double point,const double spread_points,const double expected_slippage_points,XDFSignal &orb,XDFSignal &mr)
      {
       orb=m_orb.EvaluateAt(symbol,shift,or_data,vwap,atr,ema_long_ok,ema_short_ok,min_stop_distance,entry_long,entry_short,point,spread_points,expected_slippage_points);
       mr=m_mr.EvaluateAt(symbol,shift,or_data,vwap,atr,entry_long,entry_short,point,spread_points,expected_slippage_points);
      }

   XDFScoreBreakdown EvaluateScore(const XDFSignal &signal,const XDFOpeningRange &or_data,double atr,double spread_points,double vwap_dist_points,XDFRegime regime,const XDFM15Context &m15)
     {
      return(m_scorer.Score(signal,or_data,atr,spread_points,vwap_dist_points,regime,m15));
     }

   bool EvaluateBlockers(XDFNoTradeFilter &filter,double spread_points,double max_spread,double atr,double min_atr,double atr_points,double vwap_dist_points,double max_vwap_dist,double recent_range_price,double or_width_points,const XDFM15Context &m15,bool both_sides_violated,const XDFSetupFamily family,const XDFRegime regime,const string subtype,const int orb_score_final,XDFBlockerInfo &blocker,bool &or_width_secondary_allow,double &or_width_primary_limit,double &or_width_secondary_limit,int &or_width_score_penalty)
       {
       return(filter.Allow(spread_points,max_spread,atr,min_atr,atr_points,vwap_dist_points,max_vwap_dist,recent_range_price,or_width_points,m15,both_sides_violated,family,regime,subtype,orb_score_final,blocker,or_width_secondary_allow,or_width_primary_limit,or_width_secondary_limit,or_width_score_penalty));
       }

   bool XDF_EvaluateDecision(XDFNoTradeFilter &filter,const XDFDecisionContext &ctx,XDFDecision &out_decision)
     {
      ZeroMemory(out_decision);
      out_decision.allow_trade=false;
      out_decision.has_setup=false;
      out_decision.blocker.code=BLOCKER_NONE;
      out_decision.blocker.message="";
      out_decision.selection_reason="";
      out_decision.mr_block_reason="";
      out_decision.mr_override_reason="";
      bool both_sides=(ctx.session.touched_above && ctx.session.touched_below);
      out_decision.regime=m_regime.Detect(ctx.or_data,ctx.atr_m5,ctx.vwap,ctx.mid_price,both_sides,ctx.m15,out_decision.regime_reason);

      double atr_points=(ctx.point>0.0 ? ctx.atr_m5/ctx.point : 0.0);
      double vwap_dist_points=ctx.vwap_distance_points;
      double recent_range_price=ctx.recent_range_price;
      double or_width_points=(ctx.point>0.0 ? ctx.or_data.width/ctx.point : 0.0);

      long stops_level=0;
      SymbolInfoInteger(ctx.symbol,SYMBOL_TRADE_STOPS_LEVEL,stops_level);
      double min_stop_distance=MathMax(ctx.point*5.0,(double)stops_level*ctx.point);
      EvaluateSignals(ctx.symbol,ctx.evaluated_m5_shift,ctx.or_data,ctx.vwap,ctx.atr_m5,(ctx.m15.trend_alignment>=0),(ctx.m15.trend_alignment<=0),min_stop_distance,ctx.entry_long,ctx.entry_short,ctx.point,ctx.spread_points,ctx.expected_slippage_points,out_decision.orb_signal,out_decision.mr_signal);
      out_decision.orb_subtype=out_decision.orb_signal.subtype;
      out_decision.mr_subtype=out_decision.mr_signal.subtype;

      if(out_decision.orb_signal.valid)
         out_decision.orb_score=EvaluateScore(out_decision.orb_signal,ctx.or_data,ctx.atr_m5,ctx.spread_points,vwap_dist_points,out_decision.regime,ctx.m15);
      if(out_decision.mr_signal.valid)
         out_decision.mr_score=EvaluateScore(out_decision.mr_signal,ctx.or_data,ctx.atr_m5,ctx.spread_points,vwap_dist_points,out_decision.regime,ctx.m15);
      out_decision.orb_score_raw=out_decision.orb_score.total;
      out_decision.mr_score_raw=out_decision.mr_score.total;
      out_decision.orb_score_final=out_decision.orb_score_raw;
      out_decision.mr_score_final=out_decision.mr_score_raw;
      out_decision.mr_penalty_applied=false;
      out_decision.mr_exceptional_allowed=false;

      double orb_stop_pts=0.0,orb_target_pts=0.0,orb_spread_pts=ctx.spread_points,orb_slip_pts=ctx.expected_slippage_points;
      double mr_stop_pts=0.0,mr_target_pts=0.0,mr_spread_pts=ctx.spread_points,mr_slip_pts=ctx.expected_slippage_points;
      string orb_payoff_detail,mr_payoff_detail;
      bool orb_payoff_ok=(!out_decision.orb_signal.valid || PassesPayoffGate(out_decision.orb_signal,ctx,orb_stop_pts,orb_target_pts,orb_spread_pts,orb_slip_pts,orb_payoff_detail));
      bool mr_payoff_ok=(!out_decision.mr_signal.valid || PassesPayoffGate(out_decision.mr_signal,ctx,mr_stop_pts,mr_target_pts,mr_spread_pts,mr_slip_pts,mr_payoff_detail));

      out_decision.eligible_orb=(out_decision.orb_signal.valid && orb_payoff_ok);
      out_decision.eligible_mr=(out_decision.mr_signal.valid && mr_payoff_ok);

      if(out_decision.regime==REGIME_TREND_CONTINUATION && out_decision.mr_signal.valid)
        {
         string exceptional_reason;
         bool mr_exceptional=IsExceptionalMROverrideAllowed(out_decision.regime,ctx,out_decision.mr_signal,out_decision.mr_score_final,out_decision.orb_signal,out_decision.orb_score_raw,orb_payoff_ok,mr_payoff_ok,mr_stop_pts,mr_target_pts,mr_spread_pts,mr_slip_pts,exceptional_reason);
         if(mr_exceptional)
           {
            out_decision.mr_exceptional_allowed=true;
            out_decision.mr_override_reason=exceptional_reason;
           }
         else
           {
            out_decision.eligible_mr=false;
            out_decision.mr_block_reason="TREND_CONTINUATION_DEFAULT_BLOCK";
            out_decision.selected_reject_reason=StringFormat("mr_blocked_%s",exceptional_reason);
           }
        }

      if(out_decision.eligible_orb && out_decision.eligible_mr)
         out_decision.eligible_family=SETUP_BOTH;
      else if(out_decision.eligible_orb)
         out_decision.eligible_family=SETUP_ORB_CONTINUATION;
      else if(out_decision.eligible_mr)
         out_decision.eligible_family=SETUP_MEAN_REVERSION;
      else
         out_decision.eligible_family=SETUP_NONE;

      if(out_decision.eligible_orb && out_decision.eligible_mr)
         {
          if(out_decision.regime==REGIME_TREND_CONTINUATION)
            {
             out_decision.selected_signal=out_decision.orb_signal;
             out_decision.selected_score=out_decision.orb_score;
             out_decision.selected_family=SETUP_ORB_CONTINUATION;
             out_decision.selection_reason="TREND_CONTINUATION_PREFERS_ORB";
             out_decision.selected_reject_reason="orb_default_in_trend_continuation";
             if(out_decision.mr_exceptional_allowed && out_decision.mr_score_final>=(out_decision.orb_score_final+XDF_MR_OVERRIDE_MARGIN_OVER_ORB))
               {
                out_decision.selected_signal=out_decision.mr_signal;
                out_decision.selected_score=out_decision.mr_score;
                out_decision.selected_family=SETUP_MEAN_REVERSION;
                out_decision.selection_reason="EXCEPTIONAL_MR_OVERRIDE";
                out_decision.selected_reject_reason=StringFormat("mr_exceptional_override orbFinal=%d mrFinal=%d margin=%d",out_decision.orb_score_final,out_decision.mr_score_final,XDF_MR_OVERRIDE_MARGIN_OVER_ORB);
               }
            }
          else if(out_decision.regime==REGIME_MEAN_REVERSION)
            {
             out_decision.selected_signal=(out_decision.mr_score_final>=out_decision.orb_score_final?out_decision.mr_signal:out_decision.orb_signal);
             out_decision.selected_family=out_decision.selected_signal.family;
             out_decision.selected_score=(out_decision.selected_family==SETUP_MEAN_REVERSION?out_decision.mr_score:out_decision.orb_score);
             out_decision.selection_reason="REGIME_PREFERS_MR";
             out_decision.selected_reject_reason=StringFormat("both_valid orbFinal=%d mrFinal=%d selected=%d",out_decision.orb_score_final,out_decision.mr_score_final,(int)out_decision.selected_family);
            }
          else
            {
             out_decision.selected_signal=(out_decision.orb_score_final>=out_decision.mr_score_final?out_decision.orb_signal:out_decision.mr_signal);
             out_decision.selected_family=out_decision.selected_signal.family;
             out_decision.selected_score=(out_decision.selected_family==SETUP_ORB_CONTINUATION?out_decision.orb_score:out_decision.mr_score);
             out_decision.selection_reason="ADJUSTED_SCORE_COMPARE";
             out_decision.selected_reject_reason=StringFormat("both_valid orbFinal=%d mrFinal=%d selected=%d",out_decision.orb_score_final,out_decision.mr_score_final,(int)out_decision.selected_family);
            }
         }
      else if(out_decision.eligible_orb || out_decision.eligible_mr)
           {
           if(out_decision.eligible_orb)
              out_decision.selected_signal=out_decision.orb_signal;
           else
              out_decision.selected_signal=out_decision.mr_signal;
           out_decision.selected_family=out_decision.selected_signal.family;
           out_decision.selected_score=(out_decision.selected_family==SETUP_ORB_CONTINUATION?out_decision.orb_score:out_decision.mr_score);
           if(out_decision.regime==REGIME_TREND_CONTINUATION && out_decision.selected_family==SETUP_MEAN_REVERSION)
              out_decision.selection_reason="EXCEPTIONAL_MR_OVERRIDE";
           else
              out_decision.selection_reason=(out_decision.selected_family==SETUP_ORB_CONTINUATION?"ORB_ONLY_VALID":"ONLY_MR_ELIGIBLE");
           out_decision.selected_reject_reason="single_family_eligible";
           }

      if(!out_decision.selected_signal.valid)
        {
         bool any_valid_signal=(out_decision.orb_signal.valid || out_decision.mr_signal.valid);
         if(out_decision.regime==REGIME_TREND_CONTINUATION && out_decision.mr_signal.valid && !out_decision.eligible_mr && !out_decision.eligible_orb)
           {
            out_decision.selection_reason="MR_BLOCKED_BY_REGIME";
            out_decision.blocker.code=BLOCKER_NO_SETUP;
            out_decision.blocker.message=StringFormat("mr_block_reason=%s mr_override_reason=%s",out_decision.mr_block_reason,out_decision.mr_override_reason);
            out_decision.selected_reject_reason="mr_blocked_by_regime";
           }
         else if(any_valid_signal && (!orb_payoff_ok || !mr_payoff_ok))
           {
            if(out_decision.orb_signal.valid && !orb_payoff_ok)
              {
               out_decision.selected_family=SETUP_ORB_CONTINUATION;
               out_decision.stop_dist_points=orb_stop_pts;
               out_decision.target_dist_points=orb_target_pts;
               out_decision.spread_points=orb_spread_pts;
               out_decision.expected_slip_points=orb_slip_pts;
              }
            else if(out_decision.mr_signal.valid && !mr_payoff_ok)
              {
               out_decision.selected_family=SETUP_MEAN_REVERSION;
               out_decision.stop_dist_points=mr_stop_pts;
               out_decision.target_dist_points=mr_target_pts;
               out_decision.spread_points=mr_spread_pts;
               out_decision.expected_slip_points=mr_slip_pts;
              }
            out_decision.blocker.code=BLOCKER_PAYOFF;
            out_decision.blocker.message=StringFormat("payoff_gate orb_ok=%s orb=%s mr_ok=%s mr=%s",(orb_payoff_ok?"Y":"N"),orb_payoff_detail,(mr_payoff_ok?"Y":"N"),mr_payoff_detail);
            out_decision.selected_reject_reason="payoff";
           }
         else
           {
            out_decision.blocker.code=BLOCKER_NO_SETUP;
            out_decision.blocker.message=StringFormat("no setup orb=%s(%s) mr=%s(%s)",(out_decision.orb_signal.valid?"Y":"N"),out_decision.orb_signal.reason_invalid,(out_decision.mr_signal.valid?"Y":"N"),out_decision.mr_signal.reason_invalid);
            out_decision.selected_reject_reason="no_setup";
           }
         return(false);
        }

      if(out_decision.selected_family==SETUP_ORB_CONTINUATION)
        {
         out_decision.stop_dist_points=orb_stop_pts;
         out_decision.target_dist_points=orb_target_pts;
         out_decision.spread_points=orb_spread_pts;
         out_decision.expected_slip_points=orb_slip_pts;
        }
      else
        {
         out_decision.stop_dist_points=mr_stop_pts;
         out_decision.target_dist_points=mr_target_pts;
         out_decision.spread_points=mr_spread_pts;
         out_decision.expected_slip_points=mr_slip_pts;
        }

      bool both_valid_for_fallback=(out_decision.eligible_orb && out_decision.eligible_mr);
      XDFSetupFamily primary_family=out_decision.selected_family;

      if(!EvaluateBlockers(filter,ctx.spread_points,ctx.max_spread_points,ctx.atr_m5,ctx.min_atr,atr_points,vwap_dist_points,ctx.max_vwap_distance_points,recent_range_price,or_width_points,ctx.m15,both_sides,out_decision.selected_family,out_decision.regime,out_decision.selected_signal.subtype,out_decision.orb_score_final,out_decision.blocker,out_decision.or_width_secondary_allow,out_decision.or_width_primary_limit,out_decision.or_width_secondary_limit,out_decision.or_width_score_penalty))
        {
         out_decision.primary_reject_reason=StringFormat("family=%d reason=%s", (int)primary_family, out_decision.blocker.message);
         if(both_valid_for_fallback)
           {
            out_decision.fallback_attempted=true;
            XDFSetupFamily alt_family=(primary_family==SETUP_ORB_CONTINUATION?SETUP_MEAN_REVERSION:SETUP_ORB_CONTINUATION);
            out_decision.selected_family=alt_family;
            out_decision.selected_signal=(alt_family==SETUP_ORB_CONTINUATION?out_decision.orb_signal:out_decision.mr_signal);
            out_decision.selected_score=(alt_family==SETUP_ORB_CONTINUATION?out_decision.orb_score:out_decision.mr_score);
            if(alt_family==SETUP_ORB_CONTINUATION)
              {
               out_decision.stop_dist_points=orb_stop_pts;
               out_decision.target_dist_points=orb_target_pts;
               out_decision.spread_points=orb_spread_pts;
               out_decision.expected_slip_points=orb_slip_pts;
              }
            else
              {
               out_decision.stop_dist_points=mr_stop_pts;
               out_decision.target_dist_points=mr_target_pts;
               out_decision.spread_points=mr_spread_pts;
               out_decision.expected_slip_points=mr_slip_pts;
              }
            XDFBlockerInfo alt_blocker;
            bool alt_ok=EvaluateBlockers(filter,ctx.spread_points,ctx.max_spread_points,ctx.atr_m5,ctx.min_atr,atr_points,vwap_dist_points,ctx.max_vwap_distance_points,recent_range_price,or_width_points,ctx.m15,both_sides,out_decision.selected_family,out_decision.regime,out_decision.selected_signal.subtype,out_decision.orb_score_final,alt_blocker,out_decision.or_width_secondary_allow,out_decision.or_width_primary_limit,out_decision.or_width_secondary_limit,out_decision.or_width_score_penalty);
            if(alt_ok)
              {
               out_decision.fallback_accepted=true;
               out_decision.fallback_reason=StringFormat("fallback_from=%d_to=%d", (int)primary_family, (int)alt_family);
               out_decision.selection_reason="FAMILY_FALLBACK_ACCEPT";
              }
            else
              {
               out_decision.fallback_accepted=false;
               out_decision.fallback_reason=StringFormat("fallback_from=%d_to=%d fail=%s", (int)primary_family, (int)alt_family, alt_blocker.message);
               out_decision.selection_reason="FAMILY_FALLBACK_REJECT";
               out_decision.blocker=alt_blocker;
               out_decision.selected_reject_reason="filter";
               return(false);
              }
           }
         else
           {
            out_decision.selected_reject_reason="filter";
            return(false);
           }
         }

      if(out_decision.or_width_secondary_allow && out_decision.selected_family==SETUP_ORB_CONTINUATION && out_decision.or_width_score_penalty>0)
        {
         out_decision.orb_score_final=MathMax(0,out_decision.orb_score_final-out_decision.or_width_score_penalty);
         out_decision.selected_score.total=MathMax(0,out_decision.selected_score.total-out_decision.or_width_score_penalty);
        }

      int threshold=ctx.min_setup_score;
      bool selected_preferred=true;
      if(out_decision.regime==REGIME_MIXED)
         threshold=ctx.mixed_setup_score;
      else
        {
         XDFSetupFamily preferred=(out_decision.regime==REGIME_MEAN_REVERSION?SETUP_MEAN_REVERSION:SETUP_ORB_CONTINUATION);
         if(out_decision.selected_family!=preferred)
           {
            selected_preferred=false;
            threshold=ctx.conflict_override_score;
           }
        }

      if(out_decision.selected_score.total<threshold)
        {
          out_decision.primary_reject_reason=StringFormat("family=%d score=%d<thr=%d",(int)out_decision.selected_family,out_decision.selected_score.total,threshold);
          if(both_valid_for_fallback && !out_decision.fallback_accepted)
            {
             out_decision.fallback_attempted=true;
             XDFSetupFamily current_family=out_decision.selected_family;
             XDFSetupFamily alt_family=(current_family==SETUP_ORB_CONTINUATION?SETUP_MEAN_REVERSION:SETUP_ORB_CONTINUATION);
             out_decision.selected_family=alt_family;
             out_decision.selected_signal=(alt_family==SETUP_ORB_CONTINUATION?out_decision.orb_signal:out_decision.mr_signal);
             out_decision.selected_score=(alt_family==SETUP_ORB_CONTINUATION?out_decision.orb_score:out_decision.mr_score);
             int alt_threshold=ctx.min_setup_score;
             bool alt_preferred=true;
             if(out_decision.regime==REGIME_MIXED)
                alt_threshold=ctx.mixed_setup_score;
             else
               {
                XDFSetupFamily preferred=(out_decision.regime==REGIME_MEAN_REVERSION?SETUP_MEAN_REVERSION:SETUP_ORB_CONTINUATION);
                if(alt_family!=preferred)
                  {
                   alt_preferred=false;
                   alt_threshold=ctx.conflict_override_score;
                  }
               }
             XDFBlockerInfo alt_blocker;
             if(!EvaluateBlockers(filter,ctx.spread_points,ctx.max_spread_points,ctx.atr_m5,ctx.min_atr,atr_points,vwap_dist_points,ctx.max_vwap_distance_points,recent_range_price,or_width_points,ctx.m15,both_sides,out_decision.selected_family,out_decision.regime,out_decision.selected_signal.subtype,out_decision.orb_score_final,alt_blocker,out_decision.or_width_secondary_allow,out_decision.or_width_primary_limit,out_decision.or_width_secondary_limit,out_decision.or_width_score_penalty))
               {
                out_decision.fallback_accepted=false;
                out_decision.fallback_reason=StringFormat("fallback_score_then_filter_fail %s",alt_blocker.message);
                out_decision.selection_reason="FAMILY_FALLBACK_REJECT";
                out_decision.blocker=alt_blocker;
                out_decision.selected_reject_reason="filter";
                return(false);
               }
             if(out_decision.selected_score.total<alt_threshold)
               {
                out_decision.fallback_accepted=false;
                out_decision.fallback_reason=StringFormat("fallback_score_fail score=%d<thr=%d preferred=%s",out_decision.selected_score.total,alt_threshold,(alt_preferred?"Y":"N"));
                out_decision.selection_reason="FAMILY_FALLBACK_REJECT";
                out_decision.blocker.code=BLOCKER_SCORE;
                out_decision.blocker.message=StringFormat("score %d < threshold %d (preferred=%s regime=%s)",out_decision.selected_score.total,alt_threshold,(alt_preferred?"Y":"N"),XDF_RegimeToString((int)out_decision.regime));
                out_decision.selected_reject_reason="score";
                return(false);
               }
             out_decision.fallback_accepted=true;
             out_decision.fallback_reason=StringFormat("fallback_after_score family=%d", (int)alt_family);
             out_decision.selection_reason="FAMILY_FALLBACK_ACCEPT";
            }
          else
            {
             out_decision.blocker.code=BLOCKER_SCORE;
             out_decision.blocker.message=StringFormat("score %d < threshold %d (preferred=%s regime=%s)",
                                                       out_decision.selected_score.total,threshold,(selected_preferred?"Y":"N"),XDF_RegimeToString((int)out_decision.regime));
             out_decision.selected_reject_reason="score";
             return(false);
            }
        }

      out_decision.has_setup=true;
      out_decision.allow_trade=true;
      if(out_decision.selected_reject_reason=="")
         out_decision.selected_reject_reason="accepted";
      if(out_decision.selection_reason=="")
         out_decision.selection_reason="SELECTED";
      return(true);
     }
  };

const int XDFStrategyDecisionEngine::XDF_MR_EXCEPTION_MIN_SCORE=80;
const int XDFStrategyDecisionEngine::XDF_ORB_ACCEPTABLE_QUALITY_SCORE=65;
const int XDFStrategyDecisionEngine::XDF_MR_OVERRIDE_MARGIN_OVER_ORB=10;
const double XDFStrategyDecisionEngine::XDF_M15_STRONG_CONTINUATION_SLOPE=0.08;

#endif
