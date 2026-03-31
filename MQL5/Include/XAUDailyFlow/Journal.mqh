#ifndef XAUDAILYFLOW_JOURNAL_MQH
#define XAUDAILYFLOW_JOURNAL_MQH

string XDF_RegimeToString(int regime)
  {
   if(regime==0) return("TREND_CONTINUATION");
   if(regime==1) return("MEAN_REVERSION");
   if(regime==2) return("MIXED");
   return("NO_TRADE");
  }

string XDF_SessionToString(int sess)
  {
   if(sess==0) return("LONDON");
   if(sess==1) return("NEWYORK");
   return("NONE");
  }

#endif
