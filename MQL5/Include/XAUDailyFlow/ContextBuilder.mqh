#ifndef XAUDAILYFLOW_CONTEXTBUILDER_MQH
#define XAUDAILYFLOW_CONTEXTBUILDER_MQH

#include <XAUDailyFlow/Types.mqh>
#include <XAUDailyFlow/TimeWindows.mqh>
#include <XAUDailyFlow/SessionState.mqh>
#include <XAUDailyFlow/IndicatorEngine.mqh>
#include <XAUDailyFlow/VWAPEngine.mqh>
#include <XAUDailyFlow/OpeningRangeEngine.mqh>

const double XDF_AUDIT_SPREAD_RANGE_FACTOR=0.10;

bool XDF_ValidateOpeningRange(const datetime session_start,const datetime or_end,const string symbol,const XDFOpeningRange &or_data,string &diag)
  {
   int start_shift=iBarShift(symbol,PERIOD_M1,session_start,false);
   int end_shift=iBarShift(symbol,PERIOD_M1,or_end,false);
   int count=(start_shift>=0 && end_shift>=0 ? (start_shift-end_shift) : 0);
   diag=StringFormat("OR_VALIDATE symbol=%s start=%s end=%s startShift=%d endShift=%d bars=%d high=%.2f low=%.2f width=%.2f",
                     symbol,TimeToString(session_start,TIME_DATE|TIME_MINUTES),TimeToString(or_end,TIME_DATE|TIME_MINUTES),start_shift,end_shift,count,or_data.high,or_data.low,or_data.width);
   return(or_data.valid && count>0);
  }

bool XDF_BuildDecisionContext(const string symbol,
                              const datetime ts,
                              XDFSessionRuntimeState &runtime_state,
                              XDFSessionState &session_state,
                              XDFIndicatorEngine &ind,
                              XDFVWAPEngine &vwap,
                              XDFOpeningRangeEngine &or_engine,
                              const XDFSymbolSpecs &specs,
                              const double max_spread_points,
                              const double min_atr,
                              const double max_vwap_dist_points,
                              const int min_setup_score,
                              const int mixed_setup_score,
                              const int conflict_override_score,
                              const bool live_mode,
                              datetime &last_session_start,
                              datetime &last_m1_vwap_bar,
                              XDFDecisionContext &out_ctx,
                              XDFOpeningRange &out_or,
                              string &out_diag)
  {
   out_diag="";
   ZeroMemory(out_ctx);
   if(session_state.session_start!=last_session_start)
     {
      vwap.Reset(symbol,session_state.session_start);
      last_session_start=session_state.session_start;
      last_m1_vwap_bar=0;
     }
   if(live_mode)
     {
      if(XDF_NewBar(symbol,PERIOD_M1,last_m1_vwap_bar) || vwap.Value()==0.0)
         vwap.Update();
     }
   else
      vwap.UpdateTo(ts);

   string or_diag;
   if(!or_engine.XDF_BuildExactOpeningRange(session_state.session_start,session_state.or_end,out_or,or_diag))
     {
      out_diag=or_diag;
      return(false);
     }
   string validation;
   XDF_ValidateOpeningRange(session_state.session_start,session_state.or_end,symbol,out_or,validation);
   out_diag=or_diag + " | " + validation;

   MqlRates m5[];
   ArraySetAsSeries(m5,true);
   int m5_shift=(live_mode?0:iBarShift(symbol,PERIOD_M5,ts,false));
   if(m5_shift<0) m5_shift=0;
   if(CopyRates(symbol,PERIOD_M5,m5_shift,3,m5)>=3)
      XDF_UpdateSessionTouches(runtime_state,m5[1].high,m5[1].low,out_or);
   session_state.touched_above=runtime_state.touched_above;
   session_state.touched_below=runtime_state.touched_below;

   double bid=SymbolInfoDouble(symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(symbol,SYMBOL_ASK);
   double mid=((bid>0.0 && ask>0.0)?(bid+ask)/2.0:SymbolInfoDouble(symbol,SYMBOL_LAST));
   if(mid<=0.0)
      mid=vwap.Value();

   out_ctx.symbol=symbol;
   out_ctx.or_data=out_or;
   out_ctx.session=session_state;
   out_ctx.vwap=vwap.Value();
   out_ctx.mid_price=mid;
   out_ctx.atr_m5=(live_mode?ind.ATR():ind.ATRAt(ts));
   out_ctx.spread_points=((ask>0.0 && bid>0.0 && specs.point>0.0)?((ask-bid)/specs.point):0.0);
   if(!live_mode && specs.point>0.0 && m5_shift>=1 && CopyRates(symbol,PERIOD_M5,m5_shift,2,m5)>=2)
      out_ctx.spread_points=((m5[0].high-m5[0].low)/specs.point)*XDF_AUDIT_SPREAD_RANGE_FACTOR;
   out_ctx.max_spread_points=max_spread_points;
   out_ctx.min_atr=min_atr;
   out_ctx.max_vwap_distance_points=max_vwap_dist_points;
   out_ctx.point=specs.point;
   out_ctx.allow_trade=true;
   out_ctx.min_setup_score=min_setup_score;
   out_ctx.mixed_setup_score=mixed_setup_score;
   out_ctx.conflict_override_score=conflict_override_score;
   out_ctx.m15=(live_mode?ind.BuildM15Context(mid):ind.BuildM15ContextAt(ts,mid));
   return(true);
  }

#endif
