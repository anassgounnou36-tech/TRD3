#ifndef XAUDAILYFLOW_SYMBOLSPECS_MQH
#define XAUDAILYFLOW_SYMBOLSPECS_MQH

#include <XAUDailyFlow/Types.mqh>

bool XDF_IsGoldAlias(const string sym)
  {
   string up=sym;
   StringToUpper(up);
   return(StringFind(up,"XAU")>=0 || StringFind(up,"GOLD")>=0);
  }

string XDF_ResolveSymbol(const string configured)
  {
   if(configured!="")
      return(configured);

   if(XDF_IsGoldAlias(_Symbol))
      return(_Symbol);

   int total=SymbolsTotal(true);
   for(int i=0;i<total;i++)
     {
      string s=SymbolName(i,true);
      if(XDF_IsGoldAlias(s))
         return(s);
     }
   return(_Symbol);
  }

bool XDF_LoadSymbolSpecs(const string symbol,XDFSymbolSpecs &specs)
  {
   ZeroMemory(specs);
   specs.symbol=symbol;
   long digits=0,stops=0,freeze=0;
   if(!SymbolInfoInteger(symbol,SYMBOL_DIGITS,digits)) return(false);
   if(!SymbolInfoDouble(symbol,SYMBOL_POINT,specs.point)) return(false);
   if(!SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE,specs.tick_size)) return(false);
   if(!SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE,specs.tick_value)) return(false);
   if(!SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN,specs.min_lot)) return(false);
   if(!SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX,specs.max_lot)) return(false);
   if(!SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP,specs.lot_step)) return(false);
   SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL,stops);
   SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL,freeze);
   specs.digits=(int)digits;
   specs.stops_level_points=(int)stops;
   specs.freeze_level_points=(int)freeze;
   return(true);
  }

double XDF_NormalizeVolume(const XDFSymbolSpecs &specs,double volume)
  {
   if(specs.lot_step<=0.0)
      return(volume);
   double stepped=MathFloor(volume/specs.lot_step)*specs.lot_step;
   return(NormalizeDouble(stepped,2));
  }

#endif
