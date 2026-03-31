#ifndef XAUDAILYFLOW_NOTRADEFILTER_MQH
#define XAUDAILYFLOW_NOTRADEFILTER_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFNoTradeFilter
  {
public:
   bool Allow(double spread_points,double max_spread,double atr,double min_atr,double vwap_dist_points,double max_vwap_dist,string &reason)
     {
      reason="";
      if(spread_points>max_spread)
        {
         reason="Spread too high";
         return(false);
        }
      if(atr<min_atr)
        {
         reason="ATR too low";
         return(false);
        }
      if(vwap_dist_points>max_vwap_dist)
        {
         reason="Overextended vs VWAP";
         return(false);
        }
      return(true);
     }
  };

#endif
