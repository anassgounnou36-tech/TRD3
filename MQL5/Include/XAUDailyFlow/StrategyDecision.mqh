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
   void EvaluateSignals(const string symbol,const XDFOpeningRange &or_data,double vwap,double atr,bool ema_long_ok,bool ema_short_ok,double min_stop_distance,XDFSignal &orb,XDFSignal &mr)
     {
      orb=m_orb.Evaluate(symbol,or_data,vwap,atr,ema_long_ok,ema_short_ok,min_stop_distance);
      mr=m_mr.Evaluate(symbol,or_data,vwap,atr);
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

   bool EvaluateBlockers(XDFNoTradeFilter &filter,double spread_points,double max_spread,double atr,double min_atr,double atr_points,double vwap_dist_points,double max_vwap_dist,double recent_range_price,double or_width_points,const XDFM15Context &m15,bool both_sides_violated,XDFBlockerInfo &blocker)
     {
      return(filter.Allow(spread_points,max_spread,atr,min_atr,atr_points,vwap_dist_points,max_vwap_dist,recent_range_price,or_width_points,m15,both_sides_violated,blocker));
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
      double vwap_dist_points=(ctx.point>0.0 ? MathAbs(ctx.mid_price-ctx.vwap)/ctx.point : 0.0);
      double recent_range_price=0.0;
      MqlRates m5[3];
      ArraySetAsSeries(m5,true);
      if(CopyRates(ctx.symbol,PERIOD_M5,0,3,m5)>=3)
         recent_range_price=(m5[1].high-m5[1].low);
      double or_width_points=(ctx.point>0.0 ? ctx.or_data.width/ctx.point : 0.0);
      if(!EvaluateBlockers(filter,ctx.spread_points,ctx.max_spread_points,ctx.atr_m5,ctx.min_atr,atr_points,vwap_dist_points,ctx.max_vwap_distance_points,recent_range_price,or_width_points,ctx.m15,both_sides,out_decision.blocker))
         return(false);

      long stops_level=0;
      SymbolInfoInteger(ctx.symbol,SYMBOL_TRADE_STOPS_LEVEL,stops_level);
      double min_stop_distance=MathMax(ctx.point*5.0,(double)stops_level*ctx.point);
      EvaluateSignals(ctx.symbol,ctx.or_data,ctx.vwap,ctx.atr_m5,(ctx.m15.trend_alignment>=0),(ctx.m15.trend_alignment<=0),min_stop_distance,out_decision.orb_signal,out_decision.mr_signal);
      out_decision.eligible_family=(out_decision.orb_signal.valid && out_decision.mr_signal.valid ? SETUP_NONE : (out_decision.orb_signal.valid?SETUP_ORB_CONTINUATION:(out_decision.mr_signal.valid?SETUP_MEAN_REVERSION:SETUP_NONE)));

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
           }
         else
           {
            out_decision.selected_signal=out_decision.mr_signal;
            out_decision.selected_score=out_decision.mr_score;
            out_decision.selected_family=SETUP_MEAN_REVERSION;
           }
        }
      else
        {
         out_decision.selected_signal=ChooseSignal(out_decision.orb_signal,out_decision.mr_signal,out_decision.regime);
         out_decision.selected_family=out_decision.selected_signal.family;
         out_decision.selected_score=EvaluateScore(out_decision.selected_signal,ctx.or_data,ctx.atr_m5,ctx.spread_points,vwap_dist_points,out_decision.regime,ctx.m15);
        }

      if(!out_decision.selected_signal.valid)
        {
         out_decision.blocker.code=BLOCKER_REGIME;
         out_decision.blocker.message="no valid ORB/MR setup";
         return(false);
        }

      out_decision.has_setup=true;
      out_decision.allow_trade=true;
      return(true);
     }
  };

#endif
