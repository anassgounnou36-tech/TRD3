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
   bool IsContinuationQualityORBSubtype(const string subtype) const
     {
      return(subtype=="ORB_TWO_BAR_CONFIRM" || subtype=="ORB_BREAK_RETEST_HOLD" || subtype=="ORB_BREAK_PAUSE_CONTINUE");
     }
   bool IsExceptionalMRSubtype(const string subtype) const
     {
      return(subtype=="MR_RECLAIM_THEN_MIDPOINT_CONFIRM" || subtype=="MR_FALSE_BREAK_HOLD_FAIL");
     }
   bool IsRestrictedMRSubtype(const string subtype) const
     {
      return(subtype=="MR_IMMEDIATE_SWEEP_RECLAIM" || subtype=="MR_DELAYED_RECLAIM_WINDOW");
     }
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
                         MathMax(stop_dist_pts*0.95,spread_pts*2.5+expected_slip_pts):
                         MathMax(stop_dist_pts*1.20,spread_pts*3.5+expected_slip_pts));
      double min_net=(signal.family==SETUP_ORB_CONTINUATION?spread_pts*1.5:spread_pts*2.0);
      double net_target=target_dist_pts-spread_pts-expected_slip_pts;
      bool pass=(target_dist_pts>=min_target && net_target>=min_net);
      if(!pass)
         gate_detail=StringFormat("payoff_fail target=%.1f stop=%.1f spread=%.1f slip=%.1f minTarget=%.1f net=%.1f minNet=%.1f",target_dist_pts,stop_dist_pts,spread_pts,expected_slip_pts,min_target,net_target,min_net);
      return(pass);
     }
   bool IsExceptionalMROverrideAllowed(const XDFRegime regime,const XDFDecisionContext &ctx,const XDFSignal &mr_signal,const int mr_score_raw,const int mr_score_final,const XDFSignal &orb_signal,const int orb_score_raw,const bool mr_payoff_ok,string &reason) const
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
      if(!IsExceptionalMRSubtype(mr_signal.subtype))
        {
         reason="mr_subtype_not_exceptional";
         return(false);
        }
      if(IsRestrictedMRSubtype(mr_signal.subtype) && mr_score_raw<90)
        {
         reason="mr_restricted_subtype_without_extreme_score";
         return(false);
        }
      int required_score=MathMax(ctx.min_setup_score+20,75);
      if(mr_score_raw<required_score)
        {
         reason=StringFormat("mr_score_raw_%d_below_%d",mr_score_raw,required_score);
         return(false);
        }
      if(!HasGenuineReclaim(mr_signal))
        {
         reason="mr_reclaim_not_genuine";
         return(false);
        }
      bool strong_orb_continuation=(orb_signal.valid && IsContinuationQualityORBSubtype(orb_signal.subtype) && orb_score_raw>=70 && ctx.m15.slope_strength>=0.08);
      if(strong_orb_continuation)
        {
         reason="strong_orb_continuation_present";
         return(false);
        }
      if(mr_score_final<=0)
        {
         reason="mr_score_final_nonpositive";
         return(false);
        }
      reason="mr_exceptional_allowed";
      return(true);
     }
public:
   void EvaluateSignals(const string symbol,const int shift,const XDFOpeningRange &or_data,double vwap,double atr,bool ema_long_ok,bool ema_short_ok,double min_stop_distance,double entry_long,double entry_short,XDFSignal &orb,XDFSignal &mr)
      {
       orb=m_orb.EvaluateAt(symbol,shift,or_data,vwap,atr,ema_long_ok,ema_short_ok,min_stop_distance,entry_long,entry_short);
       mr=m_mr.EvaluateAt(symbol,shift,or_data,vwap,atr,entry_long,entry_short);
      }

   XDFSignal ChooseSignal(const XDFSignal &orb,const XDFSignal &mr,XDFRegime regime)
     {
      XDFSignal chosen;
      ZeroMemory(chosen);
      if(orb.valid && mr.valid)
         chosen=(regime==REGIME_MEAN_REVERSION ? mr : orb);
      else if(orb.valid)
         chosen=orb;
      else if(mr.valid)
         chosen=mr;
      return(chosen);
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
      bool both_sides=(ctx.session.touched_above && ctx.session.touched_below);
      out_decision.regime=m_regime.Detect(ctx.or_data,ctx.atr_m5,ctx.vwap,ctx.mid_price,both_sides,ctx.m15,out_decision.regime_reason);

      double atr_points=(ctx.point>0.0 ? ctx.atr_m5/ctx.point : 0.0);
      double vwap_dist_points=ctx.vwap_distance_points;
      double recent_range_price=ctx.recent_range_price;
      double or_width_points=(ctx.point>0.0 ? ctx.or_data.width/ctx.point : 0.0);

      long stops_level=0;
      SymbolInfoInteger(ctx.symbol,SYMBOL_TRADE_STOPS_LEVEL,stops_level);
      double min_stop_distance=MathMax(ctx.point*5.0,(double)stops_level*ctx.point);
      EvaluateSignals(ctx.symbol,ctx.evaluated_m5_shift,ctx.or_data,ctx.vwap,ctx.atr_m5,(ctx.m15.trend_alignment>=0),(ctx.m15.trend_alignment<=0),min_stop_distance,ctx.entry_long,ctx.entry_short,out_decision.orb_signal,out_decision.mr_signal);
      out_decision.eligible_orb=out_decision.orb_signal.valid;
      out_decision.eligible_mr=out_decision.mr_signal.valid;
      if(out_decision.eligible_orb && out_decision.eligible_mr)
         out_decision.eligible_family=SETUP_BOTH;
      else if(out_decision.eligible_orb)
         out_decision.eligible_family=SETUP_ORB_CONTINUATION;
      else if(out_decision.eligible_mr)
         out_decision.eligible_family=SETUP_MEAN_REVERSION;
      else
         out_decision.eligible_family=SETUP_NONE;
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

      if(out_decision.regime==REGIME_TREND_CONTINUATION && out_decision.mr_signal.valid)
        {
         out_decision.mr_score_final=MathMax(0,out_decision.mr_score_final-15);
         out_decision.mr_penalty_applied=true;
        }

      out_decision.eligible_orb=(out_decision.orb_signal.valid && orb_payoff_ok);
      out_decision.eligible_mr=(out_decision.mr_signal.valid && mr_payoff_ok);
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
             out_decision.selection_reason="REGIME_PREFERS_ORB";
             out_decision.selected_reject_reason="orb_default_in_trend_continuation";

             string exceptional_reason;
             bool mr_exceptional=IsExceptionalMROverrideAllowed(out_decision.regime,ctx,out_decision.mr_signal,out_decision.mr_score_raw,out_decision.mr_score_final,out_decision.orb_signal,out_decision.orb_score_raw,mr_payoff_ok,exceptional_reason);
             if(mr_exceptional && out_decision.mr_score_final>out_decision.orb_score_final)
               {
                out_decision.selected_signal=out_decision.mr_signal;
                out_decision.selected_score=out_decision.mr_score;
                out_decision.selected_family=SETUP_MEAN_REVERSION;
                out_decision.selection_reason="EXCEPTIONAL_MR_OVERRIDE";
                out_decision.selected_reject_reason=StringFormat("mr_exceptional_override orbFinal=%d mrFinal=%d",out_decision.orb_score_final,out_decision.mr_score_final);
                out_decision.mr_exceptional_allowed=true;
               }
             else if(!mr_exceptional)
               {
                out_decision.selected_reject_reason=StringFormat("mr_disqualified_%s",exceptional_reason);
               }
             else
               {
                out_decision.selected_reject_reason=StringFormat("mr_exceptional_but_score_not_higher orbFinal=%d mrFinal=%d",out_decision.orb_score_final,out_decision.mr_score_final);
               }
            }
          else
            {
             if(out_decision.regime==REGIME_MEAN_REVERSION)
               {
                out_decision.selected_signal=(out_decision.mr_score_final>=out_decision.orb_score_final?out_decision.mr_signal:out_decision.orb_signal);
                out_decision.selected_family=out_decision.selected_signal.family;
                out_decision.selected_score=(out_decision.selected_family==SETUP_MEAN_REVERSION?out_decision.mr_score:out_decision.orb_score);
                out_decision.selection_reason="REGIME_PREFERS_MR";
               }
             else
               {
                out_decision.selected_signal=(out_decision.orb_score_final>=out_decision.mr_score_final?out_decision.orb_signal:out_decision.mr_signal);
                out_decision.selected_family=out_decision.selected_signal.family;
                out_decision.selected_score=(out_decision.selected_family==SETUP_ORB_CONTINUATION?out_decision.orb_score:out_decision.mr_score);
                out_decision.selection_reason="ADJUSTED_SCORE_COMPARE";
               }
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
           out_decision.selection_reason=(out_decision.selected_family==SETUP_ORB_CONTINUATION?"ONLY_ORB_ELIGIBLE":"ONLY_MR_ELIGIBLE");
           out_decision.selected_reject_reason="single_family_eligible";
           }

      if(!out_decision.selected_signal.valid)
        {
         bool any_valid_signal=(out_decision.orb_signal.valid || out_decision.mr_signal.valid);
         if(any_valid_signal && (!orb_payoff_ok || !mr_payoff_ok))
           {
            if(out_decision.orb_signal.valid && !orb_payoff_ok)
              {
               out_decision.selected_family=SETUP_ORB_CONTINUATION;
               out_decision.orb_subtype=out_decision.orb_signal.subtype;
               out_decision.stop_dist_points=orb_stop_pts;
               out_decision.target_dist_points=orb_target_pts;
               out_decision.spread_points=orb_spread_pts;
               out_decision.expected_slip_points=orb_slip_pts;
              }
            else if(out_decision.mr_signal.valid && !mr_payoff_ok)
              {
               out_decision.selected_family=SETUP_MEAN_REVERSION;
               out_decision.mr_subtype=out_decision.mr_signal.subtype;
               out_decision.stop_dist_points=mr_stop_pts;
               out_decision.target_dist_points=mr_target_pts;
               out_decision.spread_points=mr_spread_pts;
               out_decision.expected_slip_points=mr_slip_pts;
              }
            out_decision.blocker.code=BLOCKER_PAYOFF;
            out_decision.blocker.message=StringFormat("payoff_gate orb_ok=%s orb=%s mr_ok=%s mr=%s",
                                                      (orb_payoff_ok?"Y":"N"),orb_payoff_detail,
                                                      (mr_payoff_ok?"Y":"N"),mr_payoff_detail);
            out_decision.selected_reject_reason="payoff";
           }
         else
           {
            out_decision.blocker.code=BLOCKER_NO_SETUP;
            out_decision.blocker.message=StringFormat("no setup orb=%s(%s) mr=%s(%s)",
                                                     (out_decision.orb_signal.valid?"Y":"N"),out_decision.orb_signal.reason_invalid,
                                                     (out_decision.mr_signal.valid?"Y":"N"),out_decision.mr_signal.reason_invalid);
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

      if(!EvaluateBlockers(filter,ctx.spread_points,ctx.max_spread_points,ctx.atr_m5,ctx.min_atr,atr_points,vwap_dist_points,ctx.max_vwap_distance_points,recent_range_price,or_width_points,ctx.m15,both_sides,out_decision.selected_family,out_decision.regime,out_decision.selected_signal.subtype,out_decision.orb_score_final,out_decision.blocker,out_decision.or_width_secondary_allow,out_decision.or_width_primary_limit,out_decision.or_width_secondary_limit,out_decision.or_width_score_penalty))
        {
          out_decision.selected_reject_reason="filter";
          return(false);
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
          out_decision.blocker.code=BLOCKER_SCORE;
          out_decision.blocker.message=StringFormat("score %d < threshold %d (preferred=%s regime=%s)",
                                                   out_decision.selected_score.total,threshold,(selected_preferred?"Y":"N"),XDF_RegimeToString((int)out_decision.regime));
          out_decision.selected_reject_reason="score";
          return(false);
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

#endif
