#ifndef XAUDAILYFLOW_VWAPENGINE_MQH
#define XAUDAILYFLOW_VWAPENGINE_MQH

class XDFVWAPEngine
  {
private:
   string m_symbol;
   datetime m_session_start;
   double m_pv_sum;
   double m_v_sum;
   double m_vwap;
public:
   XDFVWAPEngine():m_session_start(0),m_pv_sum(0),m_v_sum(0),m_vwap(0){}

   void Reset(const string symbol,datetime session_start)
     {
      m_symbol=symbol;
      m_session_start=session_start;
      m_pv_sum=0;
      m_v_sum=0;
      m_vwap=0;
     }

   void Update()
     {
      if(m_symbol=="" || m_session_start==0)
         return;

      MqlRates rates[];
      ArraySetAsSeries(rates,true);
      int bars=CopyRates(m_symbol,PERIOD_M1,m_session_start,TimeCurrent(),rates);
      if(bars<=0)
         return;

      m_pv_sum=0;
      m_v_sum=0;
      for(int i=bars-1;i>=0;i--)
        {
         double typ=(rates[i].high+rates[i].low+rates[i].close)/3.0;
         double vol=(double)rates[i].tick_volume;
         m_pv_sum += typ*vol;
         m_v_sum += vol;
        }
      if(m_v_sum>0)
         m_vwap=m_pv_sum/m_v_sum;
     }

   double Value() const { return m_vwap; }

   double DistanceInPoints(double price,double point) const
     {
      if(point<=0.0)
         return(0.0);
      return(MathAbs(price-m_vwap)/point);
     }
  };

#endif
