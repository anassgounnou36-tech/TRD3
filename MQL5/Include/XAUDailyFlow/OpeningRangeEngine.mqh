#ifndef XAUDAILYFLOW_OPENINGRANGEENGINE_MQH
#define XAUDAILYFLOW_OPENINGRANGEENGINE_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFOpeningRangeEngine
  {
private:
   string m_symbol;
public:
   void Init(const string symbol){m_symbol=symbol;}

   bool Build(datetime session_start,datetime or_end,XDFOpeningRange &out_or)
     {
      ZeroMemory(out_or);
      MqlRates rates[];
      ArraySetAsSeries(rates,true);
      int bars=CopyRates(m_symbol,PERIOD_M1,session_start,or_end,rates);
      if(bars<=0)
         return(false);

      double hi=-DBL_MAX,lo=DBL_MAX;
      for(int i=0;i<bars;i++)
        {
         hi=MathMax(hi,rates[i].high);
         lo=MathMin(lo,rates[i].low);
        }
      if(hi<=lo)
         return(false);
      out_or.high=hi;
      out_or.low=lo;
      out_or.midpoint=(hi+lo)/2.0;
      out_or.width=hi-lo;
      out_or.valid=true;
      return(true);
     }
  };

#endif
