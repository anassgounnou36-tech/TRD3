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
   XDFRegime EvaluateRegime(const XDFOpeningRange &or_data,double atr,double vwap,double mid,bool both_sides_touched,double m15_slope,bool m15_long,bool m15_short,string &reason)
     {
      return(m_regime.Detect(or_data,atr,vwap,mid,both_sides_touched,m15_slope,m15_long,m15_short,reason));
     }

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

   XDFScoreBreakdown EvaluateScore(const XDFSignal &signal,const XDFOpeningRange &or_data,double atr,double spread_points,double vwap_dist_points,XDFRegime regime)
     {
      return(m_scorer.Score(signal,or_data,atr,spread_points,vwap_dist_points,regime));
     }

   bool EvaluateBlockers(XDFNoTradeFilter &filter,double spread_points,double max_spread,double atr,double min_atr,double atr_points,double vwap_dist_points,double max_vwap_dist,double recent_range_price,double or_width_points,string &reason)
     {
      return(filter.Allow(spread_points,max_spread,atr,min_atr,atr_points,vwap_dist_points,max_vwap_dist,recent_range_price,or_width_points,reason));
     }
  };

#endif
