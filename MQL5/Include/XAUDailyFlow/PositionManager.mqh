#ifndef XAUDAILYFLOW_POSITIONMANAGER_MQH
#define XAUDAILYFLOW_POSITIONMANAGER_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFPositionManager
  {
public:
   bool Read(const string symbol,XDFPositionState &state)
     {
      ZeroMemory(state);
      if(!PositionSelect(symbol))
         return(false);
      state.has_position=true;
      state.ticket=(ulong)PositionGetInteger(POSITION_TICKET);
      state.direction=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      state.entry=PositionGetDouble(POSITION_PRICE_OPEN);
      state.stop=PositionGetDouble(POSITION_SL);
      state.take_profit=PositionGetDouble(POSITION_TP);
      state.opened_at=(datetime)PositionGetInteger(POSITION_TIME);
      return(true);
     }

   bool IsTimedOut(const XDFPositionState &state,int max_hold_minutes)
     {
      if(!state.has_position)
         return(false);
      return((TimeCurrent()-state.opened_at) >= max_hold_minutes*60);
     }

   bool ShouldMoveBE(const XDFPositionState &state,double bid,double ask,double trigger_rr)
     {
      if(!state.has_position || state.stop<=0.0)
         return(false);
      double risk=MathAbs(state.entry-state.stop);
      if(risk<=0.0)
         return(false);
      double move=(state.direction>0)?(bid-state.entry):(state.entry-ask);
      return(move>=risk*trigger_rr);
     }
  };

#endif
