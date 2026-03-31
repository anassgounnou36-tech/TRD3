#ifndef XAUDAILYFLOW_SETUPSCORER_MQH
#define XAUDAILYFLOW_SETUPSCORER_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFSetupScorer
  {
public:
   XDFScoreBreakdown Score(const XDFSignal &signal,const XDFOpeningRange &or_data,double atr,double spread_points,double vwap_dist_points,XDFRegime regime)
     {
      XDFScoreBreakdown out;
      ZeroMemory(out);

      if(!signal.valid)
         return(out);

      out.range_quality=(or_data.valid && atr>0.0 && or_data.width>(atr*0.3)) ? 20 : 8;
      out.context_quality=(regime==REGIME_NO_TRADE ? 0 : (regime==REGIME_MIXED ? 14 : 20));
      out.trigger_quality=22;
      out.execution_quality=(spread_points<=60 ? 18 : 8);
      out.vwap_quality=(vwap_dist_points<=250 ? 16 : 6);
      out.noise_penalty=(spread_points>80 ? 20 : 0) + (vwap_dist_points>450 ? 10 : 0);
      out.total=out.range_quality+out.context_quality+out.trigger_quality+out.execution_quality+out.vwap_quality-out.noise_penalty;
      if(out.total<0) out.total=0;
      if(out.total>100) out.total=100;
      return(out);
     }
  };

#endif
