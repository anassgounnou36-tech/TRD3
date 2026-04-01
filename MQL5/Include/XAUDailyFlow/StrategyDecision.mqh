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

   bool EvaluateBlockers(XDFNoTradeFilter &filter,double spread_points,double max_spread,double atr,double min_atr,double atr_points,double vwap_dist_points,double max_vwap_dist,double recent_range_price,double or_width_points,const XDFM15Context &m15,bool both_sides_violated,const XDFSetupFamily family,XDFBlockerInfo &blocker)
      {
       return(filter.Allow(spread_points,max_spread,atr,min_atr,atr_points,vwap_dist_points,max_vwap_dist,recent_range_price,or_width_points,m15,both_sides_violated,family,blocker));
      }

   bool XDF_EvaluateDecision(XDFNoTradeFilter &filter,const XDFDecisionContext &ctx,XDFDecision &out_decision)
     {
      ZeroMemory(out_decision);
      out_decision.allow_trade=false;
      out_decision.has_setup=false;
      out_decision.blocker.code=BLOCKER_NONE;
      out_decision.blocker.message="";
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

      if(out_decision.orb_signal.valid && out_decision.mr_signal.valid)
        {
          if(out_decision.orb_score.total>=out_decision.mr_score.total)
            {
             out_decision.selected_signal=out_decision.orb_signal;
             out_decision.selected_score=out_decision.orb_score;
             out_decision.selected_family=SETUP_ORB_CONTINUATION;
              out_decision.selected_reject_reason=StringFormat("mr_lost_on_score_%d_vs_%d subtype=%s",out_decision.mr_score.total,out_decision.orb_score.total,out_decision.mr_subtype);
            }
          else
            {
             out_decision.selected_signal=out_decision.mr_signal;
             out_decision.selected_score=out_decision.mr_score;
             out_decision.selected_family=SETUP_MEAN_REVERSION;
              out_decision.selected_reject_reason=StringFormat("orb_lost_on_score_%d_vs_%d subtype=%s",out_decision.orb_score.total,out_decision.mr_score.total,out_decision.orb_subtype);
            }
        }
      else if(out_decision.orb_signal.valid || out_decision.mr_signal.valid)
         {
          out_decision.selected_signal=ChooseSignal(out_decision.orb_signal,out_decision.mr_signal,out_decision.regime);
          out_decision.selected_family=out_decision.selected_signal.family;
          out_decision.selected_score=EvaluateScore(out_decision.selected_signal,ctx.or_data,ctx.atr_m5,ctx.spread_points,vwap_dist_points,out_decision.regime,ctx.m15);
          out_decision.selected_reject_reason="single_family_valid";
         }

      if(!out_decision.selected_signal.valid)
        {
         out_decision.blocker.code=BLOCKER_NO_SETUP;
         out_decision.blocker.message=StringFormat("no setup orb=%s(%s) mr=%s(%s)",
                                                  (out_decision.orb_signal.valid?"Y":"N"),out_decision.orb_signal.reason_invalid,
                                                  (out_decision.mr_signal.valid?"Y":"N"),out_decision.mr_signal.reason_invalid);
         out_decision.selected_reject_reason="no_setup";
         return(false);
        }

      if(!EvaluateBlockers(filter,ctx.spread_points,ctx.max_spread_points,ctx.atr_m5,ctx.min_atr,atr_points,vwap_dist_points,ctx.max_vwap_distance_points,recent_range_price,or_width_points,ctx.m15,both_sides,out_decision.selected_family,out_decision.blocker))
        {
         out_decision.selected_reject_reason="filter";
         return(false);
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
      return(true);
     }
  };

#endif
