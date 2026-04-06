#ifndef XAUDAILYFLOW_CONTEXTBUILDER_MQH
#define XAUDAILYFLOW_CONTEXTBUILDER_MQH

#include <XAUDailyFlow/Types.mqh>
#include <XAUDailyFlow/TimeWindows.mqh>
#include <XAUDailyFlow/SessionState.mqh>
#include <XAUDailyFlow/IndicatorEngine.mqh>
#include <XAUDailyFlow/VWAPEngine.mqh>
#include <XAUDailyFlow/OpeningRangeEngine.mqh>
#include <XAUDailyFlow/BarUtils.mqh>

// In audit mode, estimate synthetic spread as 10% of closed M5 bar range to avoid zero-spread bias.
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

int XDF_OpeningRangeBarCount(const string symbol,const datetime session_start,const datetime or_end)
  {
   int start_shift=iBarShift(symbol,PERIOD_M1,session_start,false);
   int end_shift=iBarShift(symbol,PERIOD_M1,or_end,false);
   return(start_shift>=0 && end_shift>=0 ? (start_shift-end_shift) : 0);
  }

string XDF_OpeningRangeSignature(const datetime session_key,const datetime session_start,const datetime or_end,const XDFOpeningRange &or_data,const int bar_count,const bool finalized)
  {
   return(StringFormat("k=%I64d|s=%I64d|e=%I64d|b=%d|h=%.2f|l=%.2f|w=%.2f|f=%d",
                       (long)session_key,(long)session_start,(long)or_end,bar_count,or_data.high,or_data.low,or_data.width,(finalized?1:0)));
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

   const datetime session_key=session_state.session_start;
   if(runtime_state.or_session_key!=session_key)
     {
      runtime_state.or_finalized=false;
      runtime_state.or_logged=false;
      runtime_state.or_session_key=session_key;
      runtime_state.or_log_signature="";
      runtime_state.or_last_validation_signature="";
      runtime_state.cached_or.valid=false;
      runtime_state.or_bar_count=0;
     }
   if(session_state.or_complete)
     {
      if(!runtime_state.or_finalized || !runtime_state.cached_or.valid)
        {
         string or_diag;
         if(!or_engine.XDF_BuildExactOpeningRange(session_state.session_start,session_state.or_end,out_or,or_diag))
           {
            out_diag=or_diag;
            return(false);
           }
         runtime_state.cached_or=out_or;
         runtime_state.or_bar_count=XDF_OpeningRangeBarCount(symbol,session_state.session_start,session_state.or_end);
         runtime_state.or_finalized=true;
        }
      out_or=runtime_state.cached_or;
      string sig=XDF_OpeningRangeSignature(session_key,session_state.session_start,session_state.or_end,out_or,runtime_state.or_bar_count,true);
      string build_line=StringFormat("OR_FINALIZED session=%s start=%s end=%s bars=%d high=%.2f low=%.2f width=%.2f",
                                     XDF_SessionToString((int)runtime_state.current_session),
                                     TimeToString(session_state.session_start,TIME_DATE|TIME_MINUTES),
                                     TimeToString(session_state.or_end,TIME_DATE|TIME_MINUTES),
                                     runtime_state.or_bar_count,out_or.high,out_or.low,out_or.width);
      string validation;
      bool valid_now=XDF_ValidateOpeningRange(session_state.session_start,session_state.or_end,symbol,out_or,validation);
      if(valid_now && runtime_state.or_last_validation_signature!=sig)
        {
         out_diag=build_line + " | " + validation;
         runtime_state.or_last_validation_signature=sig;
        }
      else
         out_diag=build_line;
      runtime_state.or_log_signature=sig;
     }
   else
     {
      out_or.valid=false;
      out_diag=StringFormat("OR_PENDING session=%s start=%s end=%s",
                            XDF_SessionToString((int)runtime_state.current_session),
                            TimeToString(session_state.session_start,TIME_DATE|TIME_MINUTES),
                            TimeToString(session_state.or_end,TIME_DATE|TIME_MINUTES));
     }

   MqlRates m5[];
   ArraySetAsSeries(m5,true);
   int m5_shift=(live_mode?1:iBarShift(symbol,PERIOD_M5,ts,false)+1);
   if(m5_shift<1) m5_shift=1;
   int m5_count=CopyRates(symbol,PERIOD_M5,m5_shift,6,m5);
   if(m5_count<0) m5_count=0;
   if(m5_count>=1)
      XDF_UpdateSessionTouches(runtime_state,m5[0].high,m5[0].low,out_or);
   session_state.touched_above=runtime_state.touched_above;
   session_state.touched_below=runtime_state.touched_below;

   double bid=SymbolInfoDouble(symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(symbol,SYMBOL_ASK);
   double mid=((bid>0.0 && ask>0.0)?(bid+ask)/2.0:SymbolInfoDouble(symbol,SYMBOL_LAST));
   if(!live_mode && m5_count>=1)
      mid=m5[0].close;
   if(mid<=0.0)
      mid=vwap.Value();

   out_ctx.symbol=symbol;
   out_ctx.or_data=out_or;
   out_ctx.session=session_state;
   out_ctx.vwap=vwap.Value();
   out_ctx.mid_price=mid;
   out_ctx.atr_m5=(live_mode?ind.ATR():ind.ATRAt(ts));
   out_ctx.spread_points=((ask>0.0 && bid>0.0 && specs.point>0.0)?((ask-bid)/specs.point):0.0);
   if(!live_mode && specs.point>0.0 && m5_count>=1)
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
   out_ctx.evaluated_m5_shift=m5_shift;
   out_ctx.evaluated_m5_time=(m5_count>=1?m5[0].time:0);
   out_ctx.m5_closed_count=MathMin(m5_count,4);
   for(int i=0;i<out_ctx.m5_closed_count;i++)
      out_ctx.m5_closed[i]=m5[i];
   out_ctx.recent_range_price=(m5_count>=1?(m5[0].high-m5[0].low):0.0);
   out_ctx.vwap_distance_points=(specs.point>0.0?MathAbs(mid-out_ctx.vwap)/specs.point:0.0);
   double spread_price=out_ctx.spread_points*specs.point;
   if(live_mode)
     {
      out_ctx.entry_long=(ask>0.0?ask:mid+spread_price*0.5);
    out_ctx.entry_short=(bid>0.0?bid:mid-spread_price*0.5);
      }
    else
      {
       out_ctx.entry_long=mid+spread_price*0.5;
       out_ctx.entry_short=mid-spread_price*0.5;
      }
    out_ctx.expected_slippage_points=MathMin(MathMax(2.0,out_ctx.spread_points*0.15),8.0);
    out_ctx.live_mode=live_mode;
    return(true);
   }

#endif
