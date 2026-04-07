#ifndef XAUDAILYFLOW_SETUPSCORER_MQH
#define XAUDAILYFLOW_SETUPSCORER_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFSetupScorer
  {
public:
   XDFScoreBreakdown Score(const XDFSignal &signal,const XDFOpeningRange &or_data,double atr,double spread_points,double vwap_dist_points,XDFRegime regime,const XDFM15Context &m15)
      {
      XDFScoreBreakdown out;
      ZeroMemory(out);

      if(!signal.valid)
         return(out);

      double width_ratio=(atr>0.0 ? or_data.width/atr : 0.0);
      if(width_ratio>=0.6 && width_ratio<=1.8) out.range_quality=22;
      else if(width_ratio>=0.4 && width_ratio<=2.2) out.range_quality=16;
      else out.range_quality=8;

      out.context_quality=(regime==REGIME_NO_TRADE ? 0 : (regime==REGIME_MIXED ? 12 : 20));
      if(m15.slope_strength>=0.12) out.context_quality+=2;
      else if(m15.slope_strength<0.03) out.context_quality-=3;
      if(signal.direction>0 && m15.trend_long) out.context_quality+=2;
      if(signal.direction<0 && m15.trend_short) out.context_quality+=2;
      if(signal.direction>0 && m15.trend_short) out.context_quality-=3;
      if(signal.direction<0 && m15.trend_long) out.context_quality-=3;
      if(out.context_quality<0) out.context_quality=0;

      if(signal.trigger_body_ratio>=0.60) out.trigger_quality=22;
      else if(signal.trigger_body_ratio>=0.45) out.trigger_quality=16;
      else out.trigger_quality=8;
      out.trigger_quality+=MathMin(8,signal.subtype_quality/4);
      out.trigger_quality+=MathMin(5,signal.confirmation_quality/4);
      if(out.trigger_quality>30) out.trigger_quality=30;

      double rr=(signal.stop_distance>0.0 ? signal.target_distance/signal.stop_distance : 0.0);
      out.execution_quality=0;
      if(spread_points<=30) out.execution_quality+=10;
      else if(spread_points<=55) out.execution_quality+=7;
      else out.execution_quality+=2;
      if(rr>=1.2) out.execution_quality+=10;
      else if(rr>=0.9) out.execution_quality+=6;
      else out.execution_quality+=2;

      out.vwap_quality=0;
      if(signal.vwap_side_ok) out.vwap_quality+=10;
      if(vwap_dist_points<=180) out.vwap_quality+=8;
      else if(vwap_dist_points<=320) out.vwap_quality+=5;
      else out.vwap_quality+=1;
      out.vwap_quality+=MathMin(4,signal.level_hold_quality/5);
      if(out.vwap_quality>24) out.vwap_quality=24;

      out.noise_penalty=0;
      if(spread_points>70) out.noise_penalty+=14;
      if(vwap_dist_points>450) out.noise_penalty+=10;
      if(rr<0.8) out.noise_penalty+=6;
      if(signal.family==SETUP_ORB_CONTINUATION && vwap_dist_points>450)
         out.noise_penalty-=6;
      if(signal.family==SETUP_MEAN_REVERSION && vwap_dist_points>320)
         out.noise_penalty+=5;
      out.noise_penalty+=signal.extension_penalty;
      out.noise_penalty-=MathMin(4,signal.retest_quality/5);
      out.noise_penalty-=MathMin(4,signal.reclaim_window_quality/5);
      if(out.noise_penalty<0) out.noise_penalty=0;
      out.total=out.range_quality+out.context_quality+out.trigger_quality+out.execution_quality+out.vwap_quality-out.noise_penalty;
      if(out.total<0) out.total=0;
      if(out.total>100) out.total=100;
      return(out);
     }
  };

#endif
