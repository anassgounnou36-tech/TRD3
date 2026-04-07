#ifndef XAUDAILYFLOW_EXECUTIONENGINE_MQH
#define XAUDAILYFLOW_EXECUTIONENGINE_MQH

#include <Trade/Trade.mqh>
#include <XAUDailyFlow/Types.mqh>

struct XDFNormalizedTradeRequest
  {
   string symbol;
   int direction;
   double lots;
   double raw_entry;
   double raw_stop;
   double raw_tp;
   double snapped_entry;
   double entry;
   double stop;
   double tp;
   double spread_points;
   double expected_slip_points;
   string subtype;
   double stop_distance;
   double target_distance;
   double stop_points;
   double target_points;
   double gross_rr;
   double net_target_points;
   double net_rr;
   double min_required_net_rr;
   double min_stop_distance;
   int regime;
   int score;
   string family;
   int deviation;
   long trade_mode;
   long stops_level_points;
   long freeze_level_points;
   int digits;
   double point;
   ENUM_ORDER_TYPE_FILLING filling_mode;
   double volume_min;
   double volume_max;
   double volume_step;
  };

class XDFExecutionEngine
  {
private:
   static const double XDF_MIN_MODIFY_DELTA_POINTS;
   static const double XDF_VOLUME_TOLERANCE;
   static const double XDF_STEP_ALIGNMENT_TOLERANCE;
   CTrade m_trade;
   string m_symbol;
   int m_deviation;
   long m_magic;
   double m_last_spread_points;
   bool IsAcceptableOrderCheckRetcode(const uint retcode) const
     {
      return(retcode==0 || retcode==TRADE_RETCODE_DONE || retcode==TRADE_RETCODE_PLACED);
     }
   bool SanitizeRequestPrices(const string symbol,
                              const int direction,
                              const double raw_entry,
                              const double raw_stop,
                              const double raw_tp,
                              double &final_entry,
                              double &final_stop,
                              double &final_tp,
                              double &min_stop_distance,
                              long &stops_level_points,
                              long &freeze_level_points,
                              int &digits,
                              double &point,
                              string &reason) const
     {
      reason="";
      long symbol_digits=0;
      if(!SymbolInfoInteger(symbol,SYMBOL_DIGITS,symbol_digits))
        {
         reason="invalid_symbol_digits";
         return(false);
        }
      digits=(int)symbol_digits;
      point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      if(point<=0.0)
        {
         reason="invalid_symbol_point";
         return(false);
        }
      SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL,stops_level_points);
      SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL,freeze_level_points);
      min_stop_distance=MathMax((double)stops_level_points*point,point*5.0);
      double snapped=(direction>0 ? SymbolInfoDouble(symbol,SYMBOL_ASK) : SymbolInfoDouble(symbol,SYMBOL_BID));
      if(snapped<=0.0)
        {
         reason="invalid_entry_snapshot";
         return(false);
        }
      final_entry=NormalizeDouble(snapped,digits);
      final_stop=raw_stop;
      if(direction>0)
        {
         double max_stop=final_entry-min_stop_distance;
         if(final_stop<=0.0)
            final_stop=max_stop;
         else
            final_stop=MathMin(final_stop,max_stop);
         final_stop=NormalizeDouble(final_stop,digits);
         if(!(final_stop<final_entry) || (final_entry-final_stop)<min_stop_distance)
           {
            final_stop=NormalizeDouble(final_entry-min_stop_distance,digits);
            if((final_entry-final_stop)<min_stop_distance)
               final_stop=NormalizeDouble(final_stop-point,digits);
           }
         if(!(final_stop<final_entry) || (final_entry-final_stop)<min_stop_distance)
           {
            reason="invalid_stop_side";
            return(false);
           }
         final_tp=raw_tp;
         if(final_tp<=0.0 || final_tp<=final_entry)
           {
            double inferred=MathAbs(raw_tp-raw_entry);
            double fallback_dist=MathMax(inferred,min_stop_distance);
            final_tp=final_entry+fallback_dist;
           }
         final_tp=NormalizeDouble(final_tp,digits);
         if(!(final_tp>final_entry))
            final_tp=NormalizeDouble(final_entry+MathMax(min_stop_distance,point),digits);
         if(!(final_tp>final_entry))
           {
            reason="invalid_tp_side";
            return(false);
           }
        }
      else
        {
         double min_stop=final_entry+min_stop_distance;
         if(final_stop<=0.0)
            final_stop=min_stop;
         else
            final_stop=MathMax(final_stop,min_stop);
         final_stop=NormalizeDouble(final_stop,digits);
         if(!(final_stop>final_entry) || (final_stop-final_entry)<min_stop_distance)
           {
            final_stop=NormalizeDouble(final_entry+min_stop_distance,digits);
            if((final_stop-final_entry)<min_stop_distance)
               final_stop=NormalizeDouble(final_stop+point,digits);
           }
         if(!(final_stop>final_entry) || (final_stop-final_entry)<min_stop_distance)
           {
            reason="invalid_stop_side";
            return(false);
           }
         final_tp=raw_tp;
         if(final_tp<=0.0 || final_tp>=final_entry)
           {
            double inferred=MathAbs(raw_tp-raw_entry);
            double fallback_dist=MathMax(inferred,min_stop_distance);
            final_tp=final_entry-fallback_dist;
           }
         final_tp=NormalizeDouble(final_tp,digits);
         if(!(final_tp<final_entry))
            final_tp=NormalizeDouble(final_entry-MathMax(min_stop_distance,point),digits);
         if(!(final_tp<final_entry) || final_tp<=0.0)
           {
            reason="invalid_tp_side";
            return(false);
           }
        }
      return(true);
     }
   ENUM_ORDER_TYPE_FILLING ResolveFilling(const string symbol) const
     {
      long filling_flags=0;
      if(!SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE,filling_flags))
         return(ORDER_FILLING_IOC);
      // Implements filling-mode selection order for multi-mode symbols: FOK, then IOC, then BOC.
      if((filling_flags & SYMBOL_FILLING_FOK)!=0)
         return(ORDER_FILLING_FOK);
      if((filling_flags & SYMBOL_FILLING_IOC)!=0)
         return(ORDER_FILLING_IOC);
      if((filling_flags & SYMBOL_FILLING_BOC)!=0)
         return(ORDER_FILLING_BOC);
      return(ORDER_FILLING_IOC);
     }
public:
   string XDF_TradeRetcodeToString(const uint retcode) const
     {
      switch(retcode)
        {
         case TRADE_RETCODE_REQUOTE: return("TRADE_RETCODE_REQUOTE");
         case TRADE_RETCODE_REJECT: return("TRADE_RETCODE_REJECT");
         case TRADE_RETCODE_CANCEL: return("TRADE_RETCODE_CANCEL");
         case TRADE_RETCODE_PLACED: return("TRADE_RETCODE_PLACED");
         case TRADE_RETCODE_DONE: return("TRADE_RETCODE_DONE");
         case TRADE_RETCODE_DONE_PARTIAL: return("TRADE_RETCODE_DONE_PARTIAL");
         case TRADE_RETCODE_ERROR: return("TRADE_RETCODE_ERROR");
         case TRADE_RETCODE_TIMEOUT: return("TRADE_RETCODE_TIMEOUT");
         case TRADE_RETCODE_INVALID: return("TRADE_RETCODE_INVALID");
         case TRADE_RETCODE_INVALID_VOLUME: return("TRADE_RETCODE_INVALID_VOLUME");
         case TRADE_RETCODE_INVALID_PRICE: return("TRADE_RETCODE_INVALID_PRICE");
         case TRADE_RETCODE_INVALID_STOPS: return("TRADE_RETCODE_INVALID_STOPS");
         case TRADE_RETCODE_TRADE_DISABLED: return("TRADE_RETCODE_TRADE_DISABLED");
         case TRADE_RETCODE_MARKET_CLOSED: return("TRADE_RETCODE_MARKET_CLOSED");
         case TRADE_RETCODE_NO_MONEY: return("TRADE_RETCODE_NO_MONEY");
         case TRADE_RETCODE_PRICE_CHANGED: return("TRADE_RETCODE_PRICE_CHANGED");
         case TRADE_RETCODE_PRICE_OFF: return("TRADE_RETCODE_PRICE_OFF");
         case TRADE_RETCODE_INVALID_FILL: return("TRADE_RETCODE_INVALID_FILL");
         case TRADE_RETCODE_CONNECTION: return("TRADE_RETCODE_CONNECTION");
         case TRADE_RETCODE_ONLY_REAL: return("TRADE_RETCODE_ONLY_REAL");
         case TRADE_RETCODE_LIMIT_ORDERS: return("TRADE_RETCODE_LIMIT_ORDERS");
         case TRADE_RETCODE_LIMIT_VOLUME: return("TRADE_RETCODE_LIMIT_VOLUME");
         case TRADE_RETCODE_POSITION_CLOSED: return("TRADE_RETCODE_POSITION_CLOSED");
         case TRADE_RETCODE_INVALID_ORDER: return("TRADE_RETCODE_INVALID_ORDER");
         default: return(StringFormat("TRADE_RETCODE_%u",retcode));
        }
     }

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
      m_magic=magic;
      m_last_spread_points=0.0;
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(slippage_points);
      m_trade.SetTypeFillingBySymbol(m_symbol);
     }

   string RetcodeDescription(uint retcode) const
       {
        return(XDF_TradeRetcodeToString(retcode));
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
      out.raw_entry=signal.entry;
      out.raw_stop=signal.stop;
      out.raw_tp=signal.tp_hint;
      out.spread_points=spread_points;
      out.regime=regime;
      out.score=score;
       out.family=FamilyLabel((int)signal.family);
       out.subtype=signal.subtype;
      out.deviation=m_deviation;
      SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE,out.trade_mode);
      out.filling_mode=ResolveFilling(symbol);
      SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN,out.volume_min);
      SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX,out.volume_max);
      SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP,out.volume_step);
      string sanitize_reason;
      double final_entry=0.0,final_stop=0.0,final_tp=0.0,min_stop_distance=0.0,point=0.0;
      long stops_level=0,freeze_level=0;
      int digits=0;
      double snapped_entry=(out.direction>0 ? SymbolInfoDouble(symbol,SYMBOL_ASK) : SymbolInfoDouble(symbol,SYMBOL_BID));
      if(!SanitizeRequestPrices(symbol,out.direction,out.raw_entry,out.raw_stop,out.raw_tp,final_entry,final_stop,final_tp,min_stop_distance,stops_level,freeze_level,digits,point,sanitize_reason))
        {
         reason=sanitize_reason;
         return(false);
        }
      out.snapped_entry=NormalizeDouble(snapped_entry,digits);
      out.entry=final_entry;
      out.stop=final_stop;
      out.tp=final_tp;
      out.stop_distance=MathAbs(out.entry-out.stop);
      out.target_distance=MathAbs(out.tp-out.entry);
      out.min_stop_distance=min_stop_distance;
      out.stops_level_points=stops_level;
      out.freeze_level_points=freeze_level;
      out.digits=digits;
      out.point=point;
      if(out.entry<=0.0 || out.stop<=0.0 || out.tp<=0.0)
        {
         reason="invalid_request_prices";
         return(false);
        }
      return(true);
     }

   bool ValidatePreflight(const XDFNormalizedTradeRequest &req,double max_spread_points,bool session_active,bool duplicate_position,string &category,string &reason,MqlTradeCheckResult &check_result,string &check_diag) const
     {
      category="";
      reason="";
      check_diag="";
      ZeroMemory(check_result);
      if(!session_active)
        {
         category="market not tradable";
         reason="session not active";
         return(false);
        }
      if(duplicate_position)
        {
         category="order send failed";
         reason="duplicate position not allowed";
         return(false);
        }
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

       if(req.lots<(req.volume_min-XDF_VOLUME_TOLERANCE) || req.lots>(req.volume_max+XDF_VOLUME_TOLERANCE))
         {
          category="invalid volume";
          reason=StringFormat("lots %.2f outside [%.2f, %.2f]",req.lots,req.volume_min,req.volume_max);
          return(false);
         }
      if(req.volume_step>0.0)
        {
         double steps=req.lots/req.volume_step;
          if(MathAbs(steps-MathRound(steps))>XDF_STEP_ALIGNMENT_TOLERANCE)
           {
            category="invalid volume";
            reason=StringFormat("lots %.2f not aligned to step %.2f",req.lots,req.volume_step);
            return(false);
           }
        }

      int digits=req.digits;
      if(digits<=0)
        {
         long symbol_digits=0;
         SymbolInfoInteger(req.symbol,SYMBOL_DIGITS,symbol_digits);
         digits=(int)symbol_digits;
        }
      double min_stop_dist=req.min_stop_distance;
      if(min_stop_dist<=0.0)
        {
         double point=SymbolInfoDouble(req.symbol,SYMBOL_POINT);
         long stops_level=0;
         SymbolInfoInteger(req.symbol,SYMBOL_TRADE_STOPS_LEVEL,stops_level);
         min_stop_dist=MathMax((double)stops_level*point,point*5.0);
        }
      if(req.stop_distance<min_stop_dist)
        {
         category="invalid stop distance";
         reason=StringFormat("stopDist %.5f < min %.5f",req.stop_distance,min_stop_dist);
         return(false);
        }

      if(req.freeze_level_points>0 && req.stop_distance<((double)req.freeze_level_points*req.point))
        {
         category="invalid stop distance";
         reason="inside freeze level";
         return(false);
        }
      if((req.direction>0 && req.tp<=req.entry) || (req.direction<0 && req.tp>=req.entry))
        {
         category="invalid request prices";
         reason="tp side invalid after sanitize";
         return(false);
        }

      MqlTradeRequest check_req;
      ZeroMemory(check_req);
      check_req.action=TRADE_ACTION_DEAL;
      check_req.symbol=req.symbol;
      check_req.volume=req.lots;
      check_req.type=(req.direction>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      check_req.price=NormalizeDouble(req.entry,digits);
      check_req.sl=NormalizeDouble(req.stop,digits);
      check_req.tp=NormalizeDouble(req.tp,digits);
      check_req.deviation=req.deviation;
      check_req.magic=m_magic;
      check_req.type_filling=req.filling_mode;
      check_req.type_time=ORDER_TIME_GTC;
      bool check_ok=OrderCheck(check_req,check_result);
      uint check_retcode=(uint)check_result.retcode;
      bool retcode_zero_accepted=(check_retcode==0);
      check_diag=StringFormat("ORDER_CHECK ok=%s retcode=%u(%s) comment=%s margin=%.2f free=%.2f treatedRetcode0AsAccept=%s",
                              (check_ok?"Y":"N"),
                              check_retcode,
                              RetcodeDescription((int)check_retcode),
                              check_result.comment,
                              check_result.margin,
                              check_result.margin_free,
                              (retcode_zero_accepted?"Y":"N"));
      if(retcode_zero_accepted)
         check_diag=check_diag + " ORDER_CHECK retcode=0 treated_as=ACCEPT_IN_TESTER";
      if(!check_ok)
        {
         category="order send failed";
         reason="OrderCheck call failed";
         return(false);
        }
      if(!IsAcceptableOrderCheckRetcode(check_retcode))
        {
         category="order send failed";
         reason=StringFormat("order check failed %u(%s)",check_retcode,check_result.comment);
         return(false);
        }

      return(true);
     }

   bool Place(const string symbol,const XDFSignal &signal,double lots,double spread_points,double expected_slip_points,double max_spread_points,bool session_active,bool duplicate_position,int regime,int score,string &diag)
       {
       diag="";
       XDFNormalizedTradeRequest req;
       string normalize_reason;
       if(!BuildNormalizedRequest(symbol,signal,lots,spread_points,regime,score,req,normalize_reason))
         {
         diag=StringFormat("PRE_SEND_FAILED category=order send failed reason=%s",normalize_reason);
          return(false);
        }
       req.expected_slip_points=expected_slip_points;
       if(req.point>0.0)
         {
          req.stop_points=req.stop_distance/req.point;
          req.target_points=req.target_distance/req.point;
          req.gross_rr=(req.stop_points>0.0?req.target_points/req.stop_points:0.0);
         }
       XDFGeometryMetrics metrics;
       string geometry_reason;
       bool geometry_ok=XDF_PassesGeometryPolicy(signal.family,
                                                 signal.subtype,
                                                 (XDFRegime)regime,
                                                 req.stop_points,
                                                 req.target_points,
                                                 req.spread_points,
                                                 req.expected_slip_points,
                                                 signal.atr_points,
                                                 signal.or_width_points,
                                                 metrics,
                                                 geometry_reason);
       req.gross_rr=metrics.gross_rr;
       req.net_target_points=metrics.net_target_points;
       req.net_rr=metrics.net_rr;
       req.min_required_net_rr=XDF_MinNetRRForFamilyRegimeSubtype(signal.family,signal.subtype,(XDFRegime)regime);
       if(signal.family==SETUP_ORB_CONTINUATION)
          req.min_required_net_rr=MathMax(req.min_required_net_rr,0.90);
       else if(signal.family==SETUP_MEAN_REVERSION)
          req.min_required_net_rr=MathMax(req.min_required_net_rr,1.00);
       if(!geometry_ok)
         {
          diag=StringFormat("PRE_SEND_PAYOFF_FAIL symbol=%s family=%s subtype=%s regime=%s dir=%s finalStopPts=%.1f finalTargetPts=%.1f finalSpreadPts=%.1f finalSlipPts=%.1f finalGrossRR=%.2f finalNetTargetPts=%.1f finalNetRR=%.2f minRequiredNetRR=%.2f reason=%s",
                            req.symbol,req.family,req.subtype,RegimeLabel(req.regime),(req.direction>0?"BUY":"SELL"),req.stop_points,req.target_points,req.spread_points,req.expected_slip_points,req.gross_rr,req.net_target_points,req.net_rr,req.min_required_net_rr,geometry_reason);
          return(false);
         }
       m_last_spread_points=spread_points;

       MqlTradeCheckResult check_result;
       string check_diag;
       string fail_category,fail_reason;
       if(!ValidatePreflight(req,max_spread_points,session_active,duplicate_position,fail_category,fail_reason,check_result,check_diag))
         {
          diag=StringFormat("PRE_SEND symbol=%s family=%s subtype=%s regime=%s dir=%s lots=%.2f rawEntry=%.2f signalStop=%.2f signalTp=%.2f snappedEntry=%.2f finalEntry=%.2f finalStop=%.2f finalTp=%.2f finalStopPts=%.1f finalTargetPts=%.1f finalSpreadPts=%.1f finalSlipPts=%.1f finalGrossRR=%.2f finalNetTargetPts=%.1f finalNetRR=%.2f minRequiredNetRR=%.2f minStopDistance=%.5f stopDist=%.5f targetDist=%.5f deviation=%d tradeMode=%d fillMode=%d digits=%d point=%.5f stopsLevelPts=%d freezeLevelPts=%d vol[min=%.2f max=%.2f step=%.2f] score=%d preflight=FAIL category=%s reason=%s %s",
                            req.symbol,req.family,req.subtype,RegimeLabel(req.regime),(req.direction>0?"BUY":"SELL"),req.lots,req.raw_entry,req.raw_stop,req.raw_tp,req.snapped_entry,req.entry,req.stop,req.tp,req.stop_points,req.target_points,req.spread_points,req.expected_slip_points,req.gross_rr,req.net_target_points,req.net_rr,req.min_required_net_rr,req.min_stop_distance,req.stop_distance,req.target_distance,req.deviation,(int)req.trade_mode,(int)req.filling_mode,req.digits,req.point,(int)req.stops_level_points,(int)req.freeze_level_points,req.volume_min,req.volume_max,req.volume_step,req.score,fail_category,fail_reason,check_diag);
          return(false);
         }

       diag=StringFormat("PRE_SEND symbol=%s family=%s subtype=%s regime=%s dir=%s lots=%.2f rawEntry=%.2f signalStop=%.2f signalTp=%.2f snappedEntry=%.2f finalEntry=%.2f finalStop=%.2f finalTp=%.2f finalStopPts=%.1f finalTargetPts=%.1f finalSpreadPts=%.1f finalSlipPts=%.1f finalGrossRR=%.2f finalNetTargetPts=%.1f finalNetRR=%.2f minRequiredNetRR=%.2f minStopDistance=%.5f stopDist=%.5f targetDist=%.5f deviation=%d tradeMode=%d fillMode=%d digits=%d point=%.5f stopsLevelPts=%d freezeLevelPts=%d vol[min=%.2f max=%.2f step=%.2f] score=%d preflight=OK %s",
                          req.symbol,req.family,req.subtype,RegimeLabel(req.regime),(req.direction>0?"BUY":"SELL"),req.lots,req.raw_entry,req.raw_stop,req.raw_tp,req.snapped_entry,req.entry,req.stop,req.tp,req.stop_points,req.target_points,req.spread_points,req.expected_slip_points,req.gross_rr,req.net_target_points,req.net_rr,req.min_required_net_rr,req.min_stop_distance,req.stop_distance,req.target_distance,req.deviation,(int)req.trade_mode,(int)req.filling_mode,req.digits,req.point,(int)req.stops_level_points,(int)req.freeze_level_points,req.volume_min,req.volume_max,req.volume_step,req.score,check_diag);

       bool ok=false;
       if(req.direction>0)
         ok=m_trade.Buy(req.lots,req.symbol,0.0,req.stop,req.tp,signal.reason);
       else
         ok=m_trade.Sell(req.lots,req.symbol,0.0,req.stop,req.tp,signal.reason);

       uint rc=(uint)m_trade.ResultRetcode();
       if(ok)
         diag=diag + StringFormat(" | POST_SEND ok=true retcode=%d(%s) order=%I64u deal=%I64u",rc,RetcodeDescription(rc),m_trade.ResultOrder(),m_trade.ResultDeal());
       else
         diag=diag + StringFormat(" | POST_SEND ok=false category=order send failed retcode=%d(%s) order=%I64u deal=%I64u",rc,RetcodeDescription(rc),m_trade.ResultOrder(),m_trade.ResultDeal());
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
       uint rc=(uint)m_trade.ResultRetcode();
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
// Floating-point tolerance for volume bounds checks against broker min/max.
const double XDFExecutionEngine::XDF_VOLUME_TOLERANCE=1e-8;
// Floating-point tolerance for lot-step alignment checks.
const double XDFExecutionEngine::XDF_STEP_ALIGNMENT_TOLERANCE=1e-6;

#endif
