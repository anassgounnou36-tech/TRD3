#ifndef XAUDAILYFLOW_EXECUTIONENGINE_MQH
#define XAUDAILYFLOW_EXECUTIONENGINE_MQH

#include <Trade/Trade.mqh>
#include <XAUDailyFlow/Types.mqh>

class XDFExecutionEngine
  {
private:
   CTrade m_trade;
   string m_symbol;
public:
   void Configure(const string symbol,long magic,int slippage_points)
     {
      m_symbol=symbol;
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(slippage_points);
      m_trade.SetTypeFillingBySymbol(m_symbol);
     }

   bool Place(const string symbol,const XDFSignal &signal,double lots)
     {
      if(!signal.valid || lots<=0.0)
         return(false);

      if(signal.direction>0)
         return(m_trade.Buy(lots,symbol,0.0,signal.stop,signal.tp_hint,signal.reason));
      return(m_trade.Sell(lots,symbol,0.0,signal.stop,signal.tp_hint,signal.reason));
     }

   bool ModifySLTP(const string symbol,double sl,double tp)
     {
      return(m_trade.PositionModify(symbol,sl,tp));
     }
  };

#endif
