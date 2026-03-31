#ifndef XAUDAILYFLOW_TIMEWINDOWS_MQH
#define XAUDAILYFLOW_TIMEWINDOWS_MQH

#include <XAUDailyFlow/Types.mqh>

datetime XDF_DayAnchor(datetime now)
  {
   MqlDateTime dt;
   TimeToStruct(now,dt);
   dt.hour=0;dt.min=0;dt.sec=0;
   return(StructToTime(dt));
  }

void XDF_InitSessionState(XDFSessionState &state)
  {
   ZeroMemory(state);
   state.active=false;
   state.or_complete=false;
   state.touched_above=false;
   state.touched_below=false;
  }

void XDF_BuildSessionState(const XDFSessionConfig &cfg,datetime now,XDFSessionState &state)
  {
   XDF_InitSessionState(state);
   datetime anchor=XDF_DayAnchor(now);
   state.day_anchor=anchor;
   state.session_start=anchor + cfg.start_hour*3600 + cfg.start_minute*60;
   state.or_end=state.session_start + cfg.or_minutes*60;
   state.trade_end=state.session_start + cfg.trade_minutes*60;
   state.active=(now>=state.session_start && now<=state.trade_end);
   state.or_complete=(now>=state.or_end);
  }

XDFSessionId XDF_ActiveSession(datetime now,const XDFSessionConfig &london,const XDFSessionConfig &ny,XDFSessionState &out_state)
  {
   XDFSessionState lstate,nstate;
   XDF_InitSessionState(lstate);
   XDF_InitSessionState(nstate);
   XDF_BuildSessionState(london,now,lstate);
   XDF_BuildSessionState(ny,now,nstate);

   if(lstate.active)
     {
      out_state=lstate;
      return(SESSION_LONDON);
     }
   if(nstate.active)
     {
      out_state=nstate;
      return(SESSION_NEWYORK);
     }
   XDF_InitSessionState(out_state);
   return(SESSION_NONE);
  }

#endif
