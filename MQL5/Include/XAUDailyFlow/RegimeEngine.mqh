#ifndef XAUDAILYFLOW_REGIMEENGINE_MQH
#define XAUDAILYFLOW_REGIMEENGINE_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFRegimeEngine
  {
public:
   XDFRegime Detect(const XDFOpeningRange &or_data,double atr,double vwap,double price,bool both_sides_violated,double m15_slope,bool m15_long_aligned,bool m15_short_aligned)
     {
      if(!or_data.valid || atr<=0.0)
         return(REGIME_NO_TRADE);

      double width_ratio=or_data.width/atr;
      double dist=MathAbs(price-vwap);
      bool slope_up=(m15_slope>atr*0.05);
      bool slope_down=(m15_slope<-atr*0.05);
      bool trend_ctx=(slope_up && m15_long_aligned) || (slope_down && m15_short_aligned);

      if(width_ratio<0.25)
         return(REGIME_NO_TRADE);

      if(both_sides_violated && (width_ratio<1.0 || !trend_ctx))
         return(REGIME_MEAN_REVERSION);

      if(width_ratio>1.0 && trend_ctx && dist<atr*1.3)
         return(REGIME_TREND_CONTINUATION);

      if(width_ratio>=0.5 && width_ratio<=1.8)
         return(REGIME_MIXED);

      return(REGIME_MEAN_REVERSION);
     }
  };

#endif
