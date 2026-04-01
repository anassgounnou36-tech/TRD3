#ifndef XAUDAILYFLOW_EXECUTIONENGINE_MQH
#define XAUDAILYFLOW_EXECUTIONENGINE_MQH

#include <Trade/Trade.mqh>
#include <XAUDailyFlow/Types.mqh>

struct XDFNormalizedTradeRequest
  {
   string symbol;
   int direction;
   double lots;
   double entry;
   double stop;
   double tp;
   double spread_points;
   double stop_distance;
   double target_distance;
   int regime;
   int score;
   string family;
  };

class XDFExecutionEngine
  {
private:
   static const double XDF_MIN_MODIFY_DELTA_POINTS;
   CTrade m_trade;
   string m_symbol;
   int m_deviation;
   double m_last_spread_points;
   ENUM_ORDER_TYPE_FILLING ResolveFilling(const string symbol) const
     {
      long filling_flags=0;
      if(!SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE,filling_flags))
         return(ORDER_FILLING_IOC);
      // Implemented filling-mode selection order for multi-mode symbols: FOK, then IOC, then BOC.
      if((filling_flags & SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK)
         return(ORDER_FILLING_FOK);
      if((filling_flags & SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC)
         return(ORDER_FILLING_IOC);
      if((filling_flags & SYMBOL_FILLING_BOC)==SYMBOL_FILLING_BOC)
         return(ORDER_FILLING_BOC);
      return(ORDER_FILLING_IOC);
     }
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

   bool BuildNormalizedRequest(const string symbol,const XDFSignal &signal,double lots,double spread_points,int regime,int score,XDFNormalizedTradeRequest &out,string &reason) const
     {
      reason="";
      ZeroMemory(out);
      if(!signal.valid || lots<=0.0)
        {
         reason="invalid_request_model";
         return(false);
        }
      out.symbol=symbol;
      out.direction=signal.direction;
      out.lots=lots;
      if(out.direction!=1 && out.direction!=-1)
        {
         reason="invalid_direction";
         return(false);
        }
      out.entry=(signal.direction>0 ? SymbolInfoDouble(symbol,SYMBOL_ASK) : SymbolInfoDouble(symbol,SYMBOL_BID));
      out.stop=signal.stop;
      out.tp=signal.tp_hint;
      out.spread_points=spread_points;
      out.stop_distance=MathAbs(out.entry-out.stop);
      out.target_distance=MathAbs(out.tp-out.entry);
      out.regime=regime;
      out.score=score;
      out.family=FamilyLabel((int)signal.family);
      if(out.entry<=0.0 || out.stop<=0.0)
        {
         reason="invalid_request_prices";
         return(false);
        }
      if((out.direction>0 && out.stop>=out.entry) || (out.direction<0 && out.stop<=out.entry))
        {
         reason="invalid_stop_side";
         return(false);
        }
      return(true);
     }

   bool ValidatePreflight(const XDFNormalizedTradeRequest &req,double max_spread_points,string &category,string &reason,MqlTradeCheckResult &check_result,string &check_diag) const
     {
      category="";
      reason="";
      check_diag="";
      ZeroMemory(check_result);
      if(req.symbol=="")
        {
         category="invalid symbol";
         reason="empty symbol";
         return(false);
        }

      if(!SymbolSelect(req.symbol,true))
        {
         category="invalid symbol";
         reason="symbol select failed";
         return(false);
        }

      long trade_mode=SYMBOL_TRADE_MODE_DISABLED;
      SymbolInfoInteger(req.symbol,SYMBOL_TRADE_MODE,trade_mode);
      if(trade_mode==SYMBOL_TRADE_MODE_DISABLED || trade_mode==SYMBOL_TRADE_MODE_CLOSEONLY)
        {
         category="market not tradable";
         reason=StringFormat("trade mode=%d",trade_mode);
         return(false);
        }
      if(req.direction>0 && trade_mode==SYMBOL_TRADE_MODE_SHORTONLY)
        {
         category="market not tradable";
         reason="short-only mode";
         return(false);
        }
      if(req.direction<0 && trade_mode==SYMBOL_TRADE_MODE_LONGONLY)
        {
         category="market not tradable";
         reason="long-only mode";
         return(false);
        }

      if(max_spread_points>0.0 && req.spread_points>max_spread_points)
        {
         category="spread violation";
         reason=StringFormat("spread %.1f > max %.1f",req.spread_points,max_spread_points);
         return(false);
        }

      double min_vol=0.0,max_vol=0.0,vol_step=0.0;
      SymbolInfoDouble(req.symbol,SYMBOL_VOLUME_MIN,min_vol);
      SymbolInfoDouble(req.symbol,SYMBOL_VOLUME_MAX,max_vol);
      SymbolInfoDouble(req.symbol,SYMBOL_VOLUME_STEP,vol_step);
      if(req.lots<min_vol || req.lots>max_vol)
        {
         category="invalid volume";
         reason=StringFormat("lots %.2f outside [%.2f, %.2f]",req.lots,min_vol,max_vol);
         return(false);
        }
      if(vol_step>0.0)
        {
         double steps=req.lots/vol_step;
         if(MathAbs(steps-MathRound(steps))>1e-6)
           {
            category="invalid volume";
            reason=StringFormat("lots %.2f not aligned to step %.2f",req.lots,vol_step);
            return(false);
           }
        }

      double point=SymbolInfoDouble(req.symbol,SYMBOL_POINT);
      long stops_level=0,freeze_level=0;
      SymbolInfoInteger(req.symbol,SYMBOL_TRADE_STOPS_LEVEL,stops_level);
      SymbolInfoInteger(req.symbol,SYMBOL_TRADE_FREEZE_LEVEL,freeze_level);
      double min_stop_dist=MathMax((double)stops_level*point,point*5.0);
      if(req.stop_distance<min_stop_dist)
        {
         category="invalid stop distance";
         reason=StringFormat("stopDist %.5f < min %.5f",req.stop_distance,min_stop_dist);
         return(false);
        }

      if(freeze_level>0 && req.stop_distance<((double)freeze_level*point))
        {
         category="invalid stop distance";
         reason="inside freeze level";
         return(false);
        }

      MqlTradeRequest check_req;
      ZeroMemory(check_req);
      check_req.action=TRADE_ACTION_DEAL;
      check_req.symbol=req.symbol;
      check_req.volume=req.lots;
      check_req.type=(req.direction>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      check_req.price=req.entry;
      check_req.sl=req.stop;
      check_req.tp=req.tp;
      check_req.deviation=m_deviation;
      check_req.magic=0;
      check_req.type_filling=ResolveFilling(req.symbol);
      check_req.type_time=ORDER_TIME_GTC;
      if(OrderCheck(check_req,check_result))
        {
         check_diag=StringFormat("ORDER_CHECK retcode=%u(%s) margin=%.2f free=%.2f comment=%s",
                                check_result.retcode,RetcodeDescription((int)check_result.retcode),
                                check_result.margin,check_result.margin_free,check_result.comment);
         if(check_result.retcode!=TRADE_RETCODE_DONE && check_result.retcode!=TRADE_RETCODE_PLACED)
           {
            category="order send failed";
            reason=StringFormat("order check failed %u(%s)",check_result.retcode,check_result.comment);
            return(false);
           }
        }
      else
        {
         category="order send failed";
         reason="OrderCheck call failed";
         check_diag="ORDER_CHECK call_failed";
         return(false);
        }

      return(true);
     }

   bool Place(const string symbol,const XDFSignal &signal,double lots,double spread_points,double max_spread_points,int regime,int score,string &diag)
      {
       diag="";
       XDFNormalizedTradeRequest req;
       string normalize_reason;
       if(!BuildNormalizedRequest(symbol,signal,lots,spread_points,regime,score,req,normalize_reason))
        {
         diag=StringFormat("PRE_SEND_FAILED category=order send failed reason=%s",normalize_reason);
          return(false);
        }
       m_last_spread_points=spread_points;

       MqlTradeCheckResult check_result;
       string check_diag;
       string fail_category,fail_reason;
       if(!ValidatePreflight(req,max_spread_points,fail_category,fail_reason,check_result,check_diag))
        {
         diag=StringFormat("PRE_SEND symbol=%s family=%s dir=%s lots=%.2f entry=%.2f stop=%.2f tp=%.2f spreadPts=%.1f stopDist=%.5f targetDist=%.5f regime=%s score=%d deviation=%d preflight=FAIL category=%s reason=%s %s",
                           req.symbol,req.family,(req.direction>0?"BUY":"SELL"),req.lots,req.entry,req.stop,req.tp,req.spread_points,req.stop_distance,req.target_distance,RegimeLabel(req.regime),req.score,m_deviation,fail_category,fail_reason,check_diag);
         return(false);
        }

       diag=StringFormat("PRE_SEND symbol=%s family=%s dir=%s lots=%.2f entry=%.2f stop=%.2f tp=%.2f spreadPts=%.1f stopDist=%.5f targetDist=%.5f regime=%s score=%d deviation=%d preflight=OK %s",
                         req.symbol,req.family,(req.direction>0?"BUY":"SELL"),req.lots,req.entry,req.stop,req.tp,req.spread_points,req.stop_distance,req.target_distance,RegimeLabel(req.regime),req.score,m_deviation,check_diag);

       bool ok=false;
       if(req.direction>0)
         ok=m_trade.Buy(req.lots,req.symbol,0.0,req.stop,req.tp,signal.reason);
       else
         ok=m_trade.Sell(req.lots,req.symbol,0.0,req.stop,req.tp,signal.reason);

       int rc=(int)m_trade.ResultRetcode();
       if(ok)
         diag=diag + StringFormat(" | POST_SEND ok=true retcode=%d(%s) order=%I64u deal=%I64u",rc,RetcodeDescription(rc),m_trade.ResultOrder(),m_trade.ResultDeal());
       else
         diag=diag + StringFormat(" | POST_SEND ok=false category=order send failed retcode=%d(%s)",rc,RetcodeDescription(rc));
       return(ok);
      }

   bool ModifySLTP(const string symbol,double old_sl,double sl,double tp,double point,string &diag)
      {
       if(point>0.0 && MathAbs(sl-old_sl)<(point*XDF_MIN_MODIFY_DELTA_POINTS))
         {
          diag=StringFormat("MODIFY symbol=%s skipped=true reason=no_meaningful_change oldSL=%.2f newSL=%.2f tp=%.2f",symbol,old_sl,sl,tp);
          return(false);
         }
       bool ok=m_trade.PositionModify(symbol,sl,tp);
       int rc=(int)m_trade.ResultRetcode();
       if(ok)
          diag=StringFormat("MODIFY symbol=%s skipped=false oldSL=%.2f newSL=%.2f deltaSL=%.2f tp=%.2f ok=true retcode=%d(%s)",
                            symbol,old_sl,sl,(sl-old_sl),tp,rc,RetcodeDescription(rc));
       else
          diag=StringFormat("MODIFY symbol=%s skipped=false oldSL=%.2f newSL=%.2f deltaSL=%.2f tp=%.2f ok=false category=modify failed retcode=%d(%s)",
                            symbol,old_sl,sl,(sl-old_sl),tp,rc,RetcodeDescription(rc));
       return(ok);
      }
  };

const double XDFExecutionEngine::XDF_MIN_MODIFY_DELTA_POINTS=3.0;

#endif
