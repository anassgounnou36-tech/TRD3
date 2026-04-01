#ifndef XAUDAILYFLOW_INDICATORENGINE_MQH
#define XAUDAILYFLOW_INDICATORENGINE_MQH

class XDFIndicatorEngine
  {
private:
   int m_atr_handle;
   int m_m15_atr_handle;
   int m_ema_fast_handle;
   int m_ema_slow_handle;
   int m_m15_ema_fast_handle;
   int m_m15_ema_slow_handle;
   string m_symbol;
public:
   XDFIndicatorEngine():m_atr_handle(INVALID_HANDLE),m_m15_atr_handle(INVALID_HANDLE),m_ema_fast_handle(INVALID_HANDLE),m_ema_slow_handle(INVALID_HANDLE),m_m15_ema_fast_handle(INVALID_HANDLE),m_m15_ema_slow_handle(INVALID_HANDLE){}

   bool Init(const string symbol)
     {
      m_symbol=symbol;
      m_atr_handle=iATR(symbol,PERIOD_M5,14);
      m_m15_atr_handle=iATR(symbol,PERIOD_M15,14);
      m_ema_fast_handle=iMA(symbol,PERIOD_M5,9,0,MODE_EMA,PRICE_CLOSE);
      m_ema_slow_handle=iMA(symbol,PERIOD_M5,21,0,MODE_EMA,PRICE_CLOSE);
      m_m15_ema_fast_handle=iMA(symbol,PERIOD_M15,20,0,MODE_EMA,PRICE_CLOSE);
      m_m15_ema_slow_handle=iMA(symbol,PERIOD_M15,50,0,MODE_EMA,PRICE_CLOSE);
      return(m_atr_handle!=INVALID_HANDLE && m_m15_atr_handle!=INVALID_HANDLE && m_ema_fast_handle!=INVALID_HANDLE && m_ema_slow_handle!=INVALID_HANDLE &&
             m_m15_ema_fast_handle!=INVALID_HANDLE && m_m15_ema_slow_handle!=INVALID_HANDLE);
     }

   void Release()
     {
      if(m_atr_handle!=INVALID_HANDLE) IndicatorRelease(m_atr_handle);
      if(m_m15_atr_handle!=INVALID_HANDLE) IndicatorRelease(m_m15_atr_handle);
      if(m_ema_fast_handle!=INVALID_HANDLE) IndicatorRelease(m_ema_fast_handle);
      if(m_ema_slow_handle!=INVALID_HANDLE) IndicatorRelease(m_ema_slow_handle);
      if(m_m15_ema_fast_handle!=INVALID_HANDLE) IndicatorRelease(m_m15_ema_fast_handle);
      if(m_m15_ema_slow_handle!=INVALID_HANDLE) IndicatorRelease(m_m15_ema_slow_handle);
     }

   double ATR()
     {
      double buff[];
      ArraySetAsSeries(buff,true);
      if(CopyBuffer(m_atr_handle,0,1,1,buff)!=1)
         return(0.0);
      return(buff[0]);
     }

   bool EMAAligned(bool long_side)
     {
      double fast[],slow[];
      ArraySetAsSeries(fast,true);
      ArraySetAsSeries(slow,true);
      if(CopyBuffer(m_ema_fast_handle,0,1,1,fast)!=1) return(false);
      if(CopyBuffer(m_ema_slow_handle,0,1,1,slow)!=1) return(false);
      return(long_side ? (fast[0]>=slow[0]) : (fast[0]<=slow[0]));
     }

   bool M15EMAAligned(bool long_side)
     {
      double fast[],slow[];
      ArraySetAsSeries(fast,true);
      ArraySetAsSeries(slow,true);
      if(CopyBuffer(m_m15_ema_fast_handle,0,1,1,fast)!=1) return(false);
      if(CopyBuffer(m_m15_ema_slow_handle,0,1,1,slow)!=1) return(false);
      return(long_side ? (fast[0]>=slow[0]) : (fast[0]<=slow[0]));
     }

   double M15Slope()
     {
      double fast[];
      ArraySetAsSeries(fast,true);
      if(CopyBuffer(m_m15_ema_fast_handle,0,1,3,fast)!=3)
         return(0.0);
      return(fast[0]-fast[2]);
     }

   double M15FastEMA()
     {
      double fast[];
      ArraySetAsSeries(fast,true);
      if(CopyBuffer(m_m15_ema_fast_handle,0,1,1,fast)!=1)
         return(0.0);
      return(fast[0]);
     }

   double M15SlowEMA()
     {
      double slow[];
      ArraySetAsSeries(slow,true);
      if(CopyBuffer(m_m15_ema_slow_handle,0,1,1,slow)!=1)
         return(0.0);
      return(slow[0]);
     }

   double M15ATR()
     {
      double buff[];
      ArraySetAsSeries(buff,true);
      if(CopyBuffer(m_m15_atr_handle,0,1,1,buff)!=1)
         return(0.0);
      return(buff[0]);
     }

   XDFM15Context BuildM15Context(double price)
     {
      XDFM15Context ctx;
      ZeroMemory(ctx);
      ctx.fast_ema=M15FastEMA();
      ctx.slow_ema=M15SlowEMA();
      ctx.slope=M15Slope();
      ctx.atr=M15ATR();
      ctx.trend_long=(ctx.fast_ema>=ctx.slow_ema);
      ctx.trend_short=(ctx.fast_ema<=ctx.slow_ema);
      ctx.trend_alignment=(ctx.trend_long && !ctx.trend_short ? 1 : (ctx.trend_short && !ctx.trend_long ? -1 : 0));
      ctx.slope_strength=(ctx.atr>0.0 ? MathAbs(ctx.slope)/ctx.atr : 0.0);
      ctx.price_vs_fast=(price-ctx.fast_ema);
      return(ctx);
     }
  };

#endif
