#ifndef XAUDAILYFLOW_SESSIONSTATE_MQH
#define XAUDAILYFLOW_SESSIONSTATE_MQH

#include <XAUDailyFlow/Types.mqh>
#include <XAUDailyFlow/TimeWindows.mqh>

struct XDFSessionRuntimeState
  {
   XDFSessionId      current_session;
   datetime          day_anchor;
   datetime          session_start;
   datetime          or_end;
   datetime          trade_end;
   bool              or_complete;
   bool              touched_above;
   bool              touched_below;
   int               session_trade_count;
   XDFSetupFamily    last_setup_family;
   int               last_direction;
   XDFBlockerInfo    last_blocker;
  };

void XDF_InitRuntimeSessionState(XDFSessionRuntimeState &st)
  {
   ZeroMemory(st);
   st.current_session=SESSION_NONE;
   st.last_setup_family=SETUP_NONE;
   st.last_direction=0;
   st.last_blocker.code=BLOCKER_NONE;
   st.last_blocker.message="";
  }

bool XDF_IsSameActiveSession(const XDFSessionRuntimeState &st,XDFSessionId sid,const XDFSessionState &computed)
  {
   return(sid!=SESSION_NONE &&
          st.current_session==sid &&
          st.session_start==computed.session_start &&
          st.day_anchor==computed.day_anchor);
  }

void XDF_ResetForNewDay(XDFSessionRuntimeState &st,datetime day_anchor)
  {
   st.day_anchor=day_anchor;
   st.session_trade_count=0;
   st.touched_above=false;
   st.touched_below=false;
   st.last_setup_family=SETUP_NONE;
   st.last_direction=0;
   st.last_blocker.code=BLOCKER_NONE;
   st.last_blocker.message="";
  }

void XDF_ResetForNewSession(XDFSessionRuntimeState &st,XDFSessionId sid,const XDFSessionState &computed)
  {
   st.current_session=sid;
   st.day_anchor=computed.day_anchor;
   st.session_start=computed.session_start;
   st.or_end=computed.or_end;
   st.trade_end=computed.trade_end;
   st.or_complete=computed.or_complete;
   st.touched_above=false;
   st.touched_below=false;
   st.session_trade_count=0;
  }

void XDF_UpdateSessionTouches(XDFSessionRuntimeState &st,double bar_high,double bar_low,const XDFOpeningRange &or_data)
  {
   if(!or_data.valid)
      return;
   if(bar_high>or_data.high) st.touched_above=true;
   if(bar_low<or_data.low) st.touched_below=true;
  }

#endif
