#property script_show_inputs
#property strict

#include <XAUDailyFlow/SymbolSpecs.mqh>

input string InpSymbol = "";

void OnStart()
  {
   string sym=XDF_ResolveSymbol(InpSymbol);
   XDFSymbolSpecs specs;
   if(!XDF_LoadSymbolSpecs(sym,specs))
     {
      Print("Symbol diagnostics failed for ",sym);
      return;
     }

   Print("=== XAUDailyFlow Symbol Diagnostics ===");
   Print("Resolved symbol: ",specs.symbol);
   Print("Digits: ",specs.digits," Point: ",DoubleToString(specs.point,8));
   Print("TickSize: ",DoubleToString(specs.tick_size,8)," TickValue: ",DoubleToString(specs.tick_value,8));
   Print("Volume min/max/step: ",DoubleToString(specs.min_lot,2)," / ",DoubleToString(specs.max_lot,2)," / ",DoubleToString(specs.lot_step,2));
   Print("Stops level pts: ",specs.stops_level_points," Freeze level pts: ",specs.freeze_level_points);
  }
