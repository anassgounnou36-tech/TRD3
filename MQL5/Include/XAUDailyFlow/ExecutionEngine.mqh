#ifndef XAUDAILYFLOW_EXECUTIONENGINE_MQH
#define XAUDAILYFLOW_EXECUTIONENGINE_MQH

#include <Trade/Trade.mqh>
#include <XAUDailyFlow/Types.mqh>

class XDFExecutionEngine
  {
private:
   CTrade m_trade;
   string m_symbol;
   int m_deviation;
   double m_last_spread_points;
public:
   string FamilyLabel(int family) const
     {
      if(family==SETUP_ORB_CONTINUATION) return("ORB");
      if(family==SETUP_MEAN_REVERSION) return("MR");
      return("NONE");
     }

   string RegimeLabel(int regime) const
     {
      if(regime==REGIME_TREND_CONTINUATION) return("TREND_CONTINUATION");
      if(regime==REGIME_MEAN_REVERSION) return("MEAN_REVERSION");
      if(regime==REGIME_MIXED) return("MIXED");
      return("NO_TRADE");
     }

   void Configure(const string symbol,long magic,int slippage_points)
     {
      m_symbol=symbol;
      m_deviation=slippage_points;
      m_last_spread_points=0.0;
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(slippage_points);
      m_trade.SetTypeFillingBySymbol(m_symbol);
     }

   string RetcodeDescription(int retcode) const
     {
      return(EnumToString((ENUM_TRADE_RETCODE)retcode));
     }

   bool Place(const string symbol,const XDFSignal &signal,double lots,double spread_points,int regime,int score,string &diag)
     {
      diag="";
      if(!signal.valid || lots<=0.0)
         return(false);
      m_last_spread_points=spread_points;

      diag=StringFormat("PRE_SEND symbol=%s family=%s dir=%s lots=%.2f entry=%.2f stop=%.2f tp=%.2f spreadPts=%.1f stopDist=%.2f targetDist=%.2f regime=%s score=%d deviation=%d",
                        symbol,FamilyLabel((int)signal.family),(signal.direction>0?"BUY":"SELL"),lots,signal.entry,signal.stop,signal.tp_hint,spread_points,signal.stop_distance,signal.target_distance,RegimeLabel(regime),score,m_deviation);

      bool ok=false;
      if(signal.direction>0)
         ok=m_trade.Buy(lots,symbol,0.0,signal.stop,signal.tp_hint,signal.reason);
      else
         ok=m_trade.Sell(lots,symbol,0.0,signal.stop,signal.tp_hint,signal.reason);

      int rc=(int)m_trade.ResultRetcode();
      if(ok)
         diag=diag + StringFormat(" | POST_SEND ok=true retcode=%d(%s) order=%I64u deal=%I64u",rc,RetcodeDescription(rc),m_trade.ResultOrder(),m_trade.ResultDeal());
      else
         diag=diag + StringFormat(" | POST_SEND ok=false retcode=%d(%s)",rc,RetcodeDescription(rc));
      return(ok);
     }

   bool ModifySLTP(const string symbol,double old_sl,double sl,double tp,string &diag)
     {
      bool ok=m_trade.PositionModify(symbol,sl,tp);
      int rc=(int)m_trade.ResultRetcode();
      diag=StringFormat("MODIFY symbol=%s oldSL=%.2f newSL=%.2f deltaSL=%.2f tp=%.2f ok=%s retcode=%d(%s)",
                        symbol,old_sl,sl,(sl-old_sl),tp,(ok?"true":"false"),rc,RetcodeDescription(rc));
      return(ok);
     }
  };

#endif
