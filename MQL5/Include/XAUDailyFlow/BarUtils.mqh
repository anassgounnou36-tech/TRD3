#ifndef XAUDAILYFLOW_BARUTILS_MQH
#define XAUDAILYFLOW_BARUTILS_MQH

bool XDF_GetRates(const string symbol,ENUM_TIMEFRAMES tf,int count,MqlRates &rates[])
  {
   ArraySetAsSeries(rates,true);
   return(CopyRates(symbol,tf,0,count,rates)==count);
  }

double XDF_LastClosedBody(const string symbol,ENUM_TIMEFRAMES tf)
  {
   MqlRates rates[];
   if(!XDF_GetRates(symbol,tf,3,rates))
      return(0.0);
   return(MathAbs(rates[1].close-rates[1].open));
  }

bool XDF_NewBar(const string symbol,ENUM_TIMEFRAMES tf,datetime &last_bar)
  {
   datetime t=iTime(symbol,tf,0);
   if(t==0)
      return(false);
   if(t!=last_bar)
     {
      last_bar=t;
      return(true);
     }
   return(false);
  }

#endif
