#ifndef XAUDAILYFLOW_REGIMEENGINE_MQH
#define XAUDAILYFLOW_REGIMEENGINE_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFRegimeEngine
  {
public:
   XDFRegime Detect(const XDFOpeningRange &or_data,double atr,double vwap,double price,bool both_sides_violated,const XDFM15Context &m15,string &reason)
      {
       reason="";
       if(!or_data.valid || atr<=0.0)
        {
         reason="invalid_or_or_atr";
         return(REGIME_NO_TRADE);
        }

       double width_ratio=or_data.width/atr;
       double dist=MathAbs(price-vwap);
       bool slope_up=(m15.slope>atr*0.05);
       bool slope_down=(m15.slope<-atr*0.05);
       bool trend_ctx=(slope_up && m15.trend_long) || (slope_down && m15.trend_short);

      if(width_ratio<0.25)
        {
         reason="or_too_narrow";
         return(REGIME_NO_TRADE);
        }

      if(both_sides_violated && (width_ratio<1.0 || !trend_ctx))
        {
         reason="both_sides_violated_or_weak_trend";
         return(REGIME_MEAN_REVERSION);
        }

      if(width_ratio>1.0 && trend_ctx && dist<atr*1.3)
        {
         reason="wide_or_with_m15_trend_alignment";
         return(REGIME_TREND_CONTINUATION);
        }

      if(width_ratio>=0.5 && width_ratio<=1.8)
        {
         reason="mixed_width_profile";
         return(REGIME_MIXED);
        }

      reason="fallback_mean_reversion";
      return(REGIME_MEAN_REVERSION);
     }
  };

#endif
