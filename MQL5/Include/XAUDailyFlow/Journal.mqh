#ifndef XAUDAILYFLOW_JOURNAL_MQH
#define XAUDAILYFLOW_JOURNAL_MQH

string XDF_RegimeToString(int regime)
  {
   if(regime==0) return("TREND_CONTINUATION");
   if(regime==1) return("MEAN_REVERSION");
   if(regime==2) return("MIXED");
   return("NO_TRADE");
  }

string XDF_BlockerToString(XDFBlocker blocker)
  {
   if(blocker==BLOCKER_NONE) return("BLOCKER_NONE");
   if(blocker==BLOCKER_SPREAD) return("BLOCKER_SPREAD");
   if(blocker==BLOCKER_ATR) return("BLOCKER_ATR");
   if(blocker==BLOCKER_OR_TOO_NARROW) return("BLOCKER_OR_TOO_NARROW");
   if(blocker==BLOCKER_OR_TOO_WIDE) return("BLOCKER_OR_TOO_WIDE");
   if(blocker==BLOCKER_VWAP_EXTENSION) return("BLOCKER_VWAP_EXTENSION");
   if(blocker==BLOCKER_REGIME) return("BLOCKER_REGIME");
   if(blocker==BLOCKER_BIAS) return("BLOCKER_BIAS");
   if(blocker==BLOCKER_SCORE) return("BLOCKER_SCORE");
   if(blocker==BLOCKER_DAILY_LIMIT) return("BLOCKER_DAILY_LIMIT");
   if(blocker==BLOCKER_SESSION_LIMIT) return("BLOCKER_SESSION_LIMIT");
   if(blocker==BLOCKER_EXISTING_POSITION) return("BLOCKER_EXISTING_POSITION");
   if(blocker==BLOCKER_VOLUME) return("BLOCKER_VOLUME");
   if(blocker==BLOCKER_EXECUTION_PREFLIGHT) return("BLOCKER_EXECUTION_PREFLIGHT");
   if(blocker==BLOCKER_SESSION_CLOSED) return("BLOCKER_SESSION_CLOSED");
   if(blocker==BLOCKER_NO_SETUP) return("BLOCKER_NO_SETUP");
   if(blocker==BLOCKER_PAYOFF) return("BLOCKER_PAYOFF");
   return("BLOCKER_UNKNOWN");
  }

string XDF_SessionToString(int sess)
  {
   if(sess==0) return("LONDON");
   if(sess==1) return("NEWYORK");
   return("NONE");
  }

#endif
