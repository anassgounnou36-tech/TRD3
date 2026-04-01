#ifndef XAUDAILYFLOW_NOTRADEFILTER_MQH
#define XAUDAILYFLOW_NOTRADEFILTER_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFNoTradeFilter
  {
private:
   double m_avg_spread_points;
   double m_avg_or_width_points;
   double m_avg_bar_range_points;
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
   XDFNoTradeFilter():m_avg_spread_points(0.0),m_avg_or_width_points(0.0),m_avg_bar_range_points(0.0){}

public:
   string ReasonSpreadTooHigh() const { return("BLOCKER_SPREAD"); }
   string ReasonATRTooLow() const { return("BLOCKER_ATR"); }
   string ReasonVWAPOverextended() const { return("BLOCKER_VWAP_EXTENSION"); }
   string ReasonCompressionDeadSession() const { return("BLOCKER_OR_TOO_NARROW"); }

   void ResetSession()
     {
      m_avg_spread_points=0.0;
      m_avg_or_width_points=0.0;
      m_avg_bar_range_points=0.0;
     }

   bool Allow(double spread_points,double max_spread,double atr,double min_atr,double atr_points,double vwap_dist_points,double max_vwap_dist,double recent_range_price,double or_width_points,const XDFM15Context &m15,bool both_sides_violated,XDFBlockerInfo &blocker)
     {
      blocker.code=BLOCKER_NONE;
      blocker.message="";
      if(m_avg_spread_points<=0.0)
         m_avg_spread_points=spread_points;
      else
         m_avg_spread_points=(m_avg_spread_points*0.9)+(spread_points*0.1);
      if(m_avg_or_width_points<=0.0)
         m_avg_or_width_points=or_width_points;
      else
         m_avg_or_width_points=(m_avg_or_width_points*0.85)+(or_width_points*0.15);
      double recent_range_atr_ratio=(atr_points>0.0 ? recent_range_price/(atr/atr_points) : 0.0);
      if(m_avg_bar_range_points<=0.0)
         m_avg_bar_range_points=recent_range_atr_ratio;
      else
         m_avg_bar_range_points=(m_avg_bar_range_points*0.85)+(recent_range_atr_ratio*0.15);

      double adaptive_max_spread=max_spread;
      if(atr_points>0.0)
         adaptive_max_spread=MathMin(max_spread,MathMax(max_spread*XDF_SPREAD_MIN_FLOOR_RATIO,atr_points*XDF_SPREAD_ATR_MULTIPLIER));
      adaptive_max_spread=MathMax(adaptive_max_spread,m_avg_spread_points*XDF_SPREAD_AVG_MULTIPLIER);
      if(or_width_points>0.0)
         adaptive_max_spread=MathMax(adaptive_max_spread,or_width_points*XDF_SPREAD_OR_MULTIPLIER);

       if(spread_points>adaptive_max_spread)
         {
          blocker.code=BLOCKER_SPREAD;
          blocker.message=StringFormat("spread %.1f > adaptive %.1f",spread_points,adaptive_max_spread);
          return(false);
         }
      if(atr<min_atr)
         {
          blocker.code=BLOCKER_ATR;
          blocker.message=StringFormat("atr %.2f < min %.2f",atr,min_atr);
          return(false);
         }
      double adaptive_vwap_limit=max_vwap_dist;
      if(atr_points>0.0)
         adaptive_vwap_limit=MathMin(max_vwap_dist,MathMax(max_vwap_dist*0.70,atr_points*XDF_VWAP_ATR_MULTIPLIER));
      if(or_width_points>0.0)
         adaptive_vwap_limit=MathMin(adaptive_vwap_limit,MathMax(max_vwap_dist*0.55,or_width_points*XDF_VWAP_OR_MULTIPLIER));
      if(vwap_dist_points>adaptive_vwap_limit)
         {
          blocker.code=BLOCKER_VWAP_EXTENSION;
          blocker.message=StringFormat("vwapDist %.1f > adaptive %.1f",vwap_dist_points,adaptive_vwap_limit);
          return(false);
         }
      if(atr_points>0.0 && vwap_dist_points>(atr_points*XDF_VWAP_ATR_MULTIPLIER))
         {
          blocker.code=BLOCKER_VWAP_EXTENSION;
          blocker.message=StringFormat("vwapDist %.1f > atrFactor %.1f",vwap_dist_points,atr_points*XDF_VWAP_ATR_MULTIPLIER);
          return(false);
         }
      if(atr_points>0.0 && or_width_points>0.0)
        {
         double min_or=MathMax(atr_points*XDF_OR_ATR_MIN_MULTIPLIER,m_avg_or_width_points*XDF_OR_BEHAVIOR_MIN_MULTIPLIER);
         double max_or=MathMin(atr_points*XDF_OR_ATR_MAX_MULTIPLIER,MathMax(m_avg_or_width_points*XDF_OR_BEHAVIOR_MAX_MULTIPLIER,min_or*1.2));
          if(or_width_points<min_or || or_width_points>max_or)
            {
             blocker.code=(or_width_points<min_or?BLOCKER_OR_TOO_NARROW:BLOCKER_OR_TOO_WIDE);
             blocker.message=StringFormat("orWidth %.1f outside [%.1f, %.1f]",or_width_points,min_or,max_or);
             return(false);
            }
         }
      if(atr<(min_atr*XDF_COMPRESSION_ATR_NEAR_FACTOR) && recent_range_price<(atr*XDF_COMPRESSION_RANGE_ATR_RATIO))
         {
          blocker.code=BLOCKER_ATR;
          blocker.message="dead session compression near ATR floor";
          return(false);
         }
      if(m_avg_bar_range_points>0.0 && recent_range_atr_ratio<(m_avg_bar_range_points*XDF_COMPRESSION_BEHAVIOR_RATIO))
         {
          blocker.code=BLOCKER_OR_TOO_NARROW;
          blocker.message="range compression below session behavior";
          return(false);
         }
      if(both_sides_violated && m15.slope_strength<0.05)
         {
          blocker.code=BLOCKER_REGIME;
          blocker.message="two-sided violation with weak M15 slope";
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
