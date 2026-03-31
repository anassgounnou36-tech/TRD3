#ifndef XAUDAILYFLOW_NOTRADEFILTER_MQH
#define XAUDAILYFLOW_NOTRADEFILTER_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFNoTradeFilter
  {
public:
   string ReasonSpreadTooHigh() const { return("BLOCK_SPREAD_TOO_HIGH"); }
   string ReasonATRTooLow() const { return("BLOCK_ATR_TOO_LOW"); }
   string ReasonVWAPOverextended() const { return("BLOCK_VWAP_OVEREXTENSION"); }

   bool Allow(double spread_points,double max_spread,double atr,double min_atr,double vwap_dist_points,double max_vwap_dist,string &reason)
     {
      reason="";
      if(spread_points>max_spread)
        {
         reason=ReasonSpreadTooHigh();
         return(false);
        }
      if(atr<min_atr)
        {
         reason=ReasonATRTooLow();
         return(false);
        }
      if(vwap_dist_points>max_vwap_dist)
        {
         reason=ReasonVWAPOverextended();
         return(false);
        }
      return(true);
     }
  };

#endif
