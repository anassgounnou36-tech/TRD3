#ifndef XAUDAILYFLOW_REGIMEENGINE_MQH
#define XAUDAILYFLOW_REGIMEENGINE_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFRegimeEngine
  {
public:
   XDFRegime Detect(const XDFOpeningRange &or_data,double atr,double vwap,double price,bool both_sides_violated,double m15_slope)
     {
      if(!or_data.valid || atr<=0.0)
         return(REGIME_NO_TRADE);

      double width_ratio=or_data.width/atr;
      double dist=MathAbs(price-vwap);

      if(width_ratio<0.25)
         return(REGIME_NO_TRADE);

      if(both_sides_violated && width_ratio<0.8)
         return(REGIME_MEAN_REVERSION);

      if(width_ratio>1.2 && m15_slope!=0.0 && dist<atr*1.5)
         return(REGIME_TREND_CONTINUATION);

      if(width_ratio>=0.5 && width_ratio<=1.5)
         return(REGIME_MIXED);

      return(REGIME_MEAN_REVERSION);
     }
  };

#endif
