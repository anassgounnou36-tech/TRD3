#ifndef XAUDAILYFLOW_NOTRADEFILTER_MQH
#define XAUDAILYFLOW_NOTRADEFILTER_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFNoTradeFilter
  {
private:
   double m_avg_spread_points;
   double m_avg_or_width_points;
   double m_avg_range_points;
   static const double XDF_SPREAD_ATR_MULTIPLIER;
   static const double XDF_SPREAD_MIN_FLOOR_RATIO;
   static const double XDF_SPREAD_AVG_MULTIPLIER;
   static const double XDF_SPREAD_OR_MULTIPLIER;
   static const double XDF_VWAP_ATR_MULTIPLIER;
   static const double XDF_VWAP_OR_MULTIPLIER;
   static const double XDF_OR_ATR_MIN_MULTIPLIER;
   static const double XDF_OR_ATR_MAX_MULTIPLIER;
   static const double XDF_OR_BEHAVIOR_MIN_MULTIPLIER;
   static const double XDF_OR_BEHAVIOR_MAX_MULTIPLIER;
   static const double XDF_COMPRESSION_ATR_NEAR_FACTOR;
   static const double XDF_COMPRESSION_RANGE_ATR_RATIO;
   static const double XDF_COMPRESSION_BEHAVIOR_RATIO;
public:
   XDFNoTradeFilter():m_avg_spread_points(0.0),m_avg_or_width_points(0.0),m_avg_range_points(0.0){}

public:
   string ReasonSpreadTooHigh() const { return("BLOCK_SPREAD_TOO_HIGH"); }
   string ReasonATRTooLow() const { return("BLOCK_ATR_TOO_LOW"); }
   string ReasonVWAPOverextended() const { return("BLOCK_VWAP_OVEREXTENSION"); }
   string ReasonCompressionDeadSession() const { return("BLOCK_DEAD_SESSION_COMPRESSION"); }

   void ResetSession()
     {
      m_avg_spread_points=0.0;
      m_avg_or_width_points=0.0;
      m_avg_range_points=0.0;
     }

   bool Allow(double spread_points,double max_spread,double atr,double min_atr,double atr_points,double vwap_dist_points,double max_vwap_dist,double recent_range_price,double or_width_points,string &reason)
     {
      reason="";
      if(m_avg_spread_points<=0.0)
         m_avg_spread_points=spread_points;
      else
         m_avg_spread_points=(m_avg_spread_points*0.9)+(spread_points*0.1);
      if(m_avg_or_width_points<=0.0)
         m_avg_or_width_points=or_width_points;
      else
         m_avg_or_width_points=(m_avg_or_width_points*0.85)+(or_width_points*0.15);
      double recent_range_points=(atr_points>0.0 ? recent_range_price/(atr/atr_points) : 0.0);
      if(m_avg_range_points<=0.0)
         m_avg_range_points=recent_range_points;
      else
         m_avg_range_points=(m_avg_range_points*0.85)+(recent_range_points*0.15);

      double adaptive_max_spread=max_spread;
      if(atr_points>0.0)
         adaptive_max_spread=MathMin(max_spread,MathMax(max_spread*XDF_SPREAD_MIN_FLOOR_RATIO,atr_points*XDF_SPREAD_ATR_MULTIPLIER));
      adaptive_max_spread=MathMax(adaptive_max_spread,m_avg_spread_points*XDF_SPREAD_AVG_MULTIPLIER);
      if(or_width_points>0.0)
         adaptive_max_spread=MathMax(adaptive_max_spread,or_width_points*XDF_SPREAD_OR_MULTIPLIER);

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
      double adaptive_vwap_limit=max_vwap_dist;
      if(atr_points>0.0)
         adaptive_vwap_limit=MathMin(max_vwap_dist,MathMax(max_vwap_dist*0.70,atr_points*XDF_VWAP_ATR_MULTIPLIER));
      if(or_width_points>0.0)
         adaptive_vwap_limit=MathMin(adaptive_vwap_limit,MathMax(max_vwap_dist*0.55,or_width_points*XDF_VWAP_OR_MULTIPLIER));
      if(vwap_dist_points>adaptive_vwap_limit)
        {
         reason=ReasonVWAPOverextended();
         return(false);
        }
      if(atr_points>0.0 && vwap_dist_points>(atr_points*XDF_VWAP_ATR_MULTIPLIER))
        {
         reason=ReasonVWAPOverextended();
         return(false);
        }
      if(atr_points>0.0 && or_width_points>0.0)
        {
         double min_or=MathMax(atr_points*XDF_OR_ATR_MIN_MULTIPLIER,m_avg_or_width_points*XDF_OR_BEHAVIOR_MIN_MULTIPLIER);
         double max_or=MathMin(atr_points*XDF_OR_ATR_MAX_MULTIPLIER,MathMax(m_avg_or_width_points*XDF_OR_BEHAVIOR_MAX_MULTIPLIER,min_or*1.2));
         if(or_width_points<min_or || or_width_points>max_or)
           {
            reason=ReasonCompressionDeadSession();
            return(false);
           }
        }
      if(atr<(min_atr*XDF_COMPRESSION_ATR_NEAR_FACTOR) && recent_range_price<(atr*XDF_COMPRESSION_RANGE_ATR_RATIO))
        {
         reason=ReasonCompressionDeadSession();
         return(false);
        }
      if(m_avg_range_points>0.0 && recent_range_points<(m_avg_range_points*XDF_COMPRESSION_BEHAVIOR_RATIO))
        {
         reason=ReasonCompressionDeadSession();
         return(false);
        }
      return(true);
     }
  };

const double XDFNoTradeFilter::XDF_SPREAD_ATR_MULTIPLIER=0.45;
const double XDFNoTradeFilter::XDF_SPREAD_MIN_FLOOR_RATIO=0.70;
const double XDFNoTradeFilter::XDF_SPREAD_AVG_MULTIPLIER=1.50;
const double XDFNoTradeFilter::XDF_SPREAD_OR_MULTIPLIER=0.30;
const double XDFNoTradeFilter::XDF_VWAP_ATR_MULTIPLIER=2.0;
const double XDFNoTradeFilter::XDF_VWAP_OR_MULTIPLIER=1.8;
const double XDFNoTradeFilter::XDF_OR_ATR_MIN_MULTIPLIER=0.30;
const double XDFNoTradeFilter::XDF_OR_ATR_MAX_MULTIPLIER=2.30;
const double XDFNoTradeFilter::XDF_OR_BEHAVIOR_MIN_MULTIPLIER=0.45;
const double XDFNoTradeFilter::XDF_OR_BEHAVIOR_MAX_MULTIPLIER=1.90;
const double XDFNoTradeFilter::XDF_COMPRESSION_ATR_NEAR_FACTOR=1.15;
const double XDFNoTradeFilter::XDF_COMPRESSION_RANGE_ATR_RATIO=0.35;
const double XDFNoTradeFilter::XDF_COMPRESSION_BEHAVIOR_RATIO=0.55;

#endif
