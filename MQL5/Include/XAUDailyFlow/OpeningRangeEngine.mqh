#ifndef XAUDAILYFLOW_OPENINGRANGEENGINE_MQH
#define XAUDAILYFLOW_OPENINGRANGEENGINE_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFOpeningRangeEngine
  {
private:
   string m_symbol;
public:
   void Init(const string symbol){m_symbol=symbol;}

   bool XDF_BuildExactOpeningRange(datetime session_start,datetime or_end,XDFOpeningRange &out_or,string &debug_diag)
     {
      debug_diag="";
      ZeroMemory(out_or);
      if(or_end<=session_start)
         return(false);
      int bars_needed=(int)((or_end-session_start)/60);
      if(bars_needed<=0)
         return(false);

      int start_shift=iBarShift(m_symbol,PERIOD_M1,session_start,false);
      int end_shift=iBarShift(m_symbol,PERIOD_M1,or_end,false);
      if(start_shift<0 || end_shift<0)
         return(false);

      int count=(start_shift-end_shift);
      if(count<=0)
         return(false);
      if(count>bars_needed)
         count=bars_needed;

      double hi=-DBL_MAX,lo=DBL_MAX;
      for(int s=start_shift;s>start_shift-count;s--)
        {
         MqlRates one[1];
         if(CopyRates(m_symbol,PERIOD_M1,s,1,one)!=1)
            return(false);
         hi=MathMax(hi,one[0].high);
         lo=MathMin(lo,one[0].low);
        }
      if(hi<=lo)
         return(false);

      out_or.high=hi;
      out_or.low=lo;
      out_or.midpoint=(hi+lo)/2.0;
      out_or.width=hi-lo;
      out_or.valid=true;
      debug_diag=StringFormat("OR_EXACT start=%s end=%s bars=%d startShift=%d endShift=%d high=%.2f low=%.2f width=%.2f",
                              TimeToString(session_start,TIME_DATE|TIME_MINUTES),TimeToString(or_end,TIME_DATE|TIME_MINUTES),count,start_shift,end_shift,out_or.high,out_or.low,out_or.width);
      return(true);
     }

   bool Build(datetime session_start,datetime or_end,XDFOpeningRange &out_or)
     {
      string dbg;
      return(XDF_BuildExactOpeningRange(session_start,or_end,out_or,dbg));
     }
  };

#endif
