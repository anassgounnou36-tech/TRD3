#ifndef XAUDAILYFLOW_NOTRADEFILTER_MQH
#define XAUDAILYFLOW_NOTRADEFILTER_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFNoTradeFilter
  {
private:
   double m_avg_spread_points;
public:
   XDFNoTradeFilter():m_avg_spread_points(0.0){}

public:
   string ReasonSpreadTooHigh() const { return("BLOCK_SPREAD_TOO_HIGH"); }
   string ReasonATRTooLow() const { return("BLOCK_ATR_TOO_LOW"); }
   string ReasonVWAPOverextended() const { return("BLOCK_VWAP_OVEREXTENSION"); }
   string ReasonCompressionDeadSession() const { return("BLOCK_DEAD_SESSION_COMPRESSION"); }

   void ResetSession()
     {
      m_avg_spread_points=0.0;
     }

   bool Allow(double spread_points,double max_spread,double atr,double min_atr,double atr_points,double vwap_dist_points,double max_vwap_dist,double recent_range_price,string &reason)
     {
      reason="";
      if(m_avg_spread_points<=0.0)
         m_avg_spread_points=spread_points;
      else
         m_avg_spread_points=(m_avg_spread_points*0.9)+(spread_points*0.1);

      double adaptive_max_spread=max_spread;
      if(atr_points>0.0)
         adaptive_max_spread=MathMin(max_spread,MathMax(max_spread*0.7,atr_points*0.45));
      adaptive_max_spread=MathMax(adaptive_max_spread,m_avg_spread_points*1.5);

      if(spread_points>adaptive_max_spread)
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
      if(atr_points>0.0 && vwap_dist_points>(atr_points*2.0))
        {
         reason=ReasonVWAPOverextended();
         return(false);
        }
      if(atr<(min_atr*1.15) && recent_range_price<(atr*0.35))
        {
         reason=ReasonCompressionDeadSession();
         return(false);
        }
      return(true);
     }
  };

#endif
