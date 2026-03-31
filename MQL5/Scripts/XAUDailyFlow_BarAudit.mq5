#property script_show_inputs
#property strict

input string InpSymbol = "";
input ENUM_TIMEFRAMES InpTF = PERIOD_M5;
input int InpBars = 20;

string ResolveSymbol(const string configured)
  {
   if(configured!="")
      return(configured);
   return(_Symbol);
  }

void OnStart()
  {
   string sym=ResolveSymbol(InpSymbol);
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int copied=CopyRates(sym,InpTF,0,InpBars,rates);
   if(copied<=0)
     {
      Print("Bar audit failed for symbol ",sym);
      return;
     }

   Print("=== XAUDailyFlow Bar Audit ===");
   Print("Symbol=",sym," TF=",EnumToString(InpTF)," Bars=",copied);
   for(int i=copied-1;i>=0;i--)
     {
      Print(TimeToString(rates[i].time,TIME_DATE|TIME_MINUTES),
            " O=",DoubleToString(rates[i].open,_Digits),
            " H=",DoubleToString(rates[i].high,_Digits),
            " L=",DoubleToString(rates[i].low,_Digits),
            " C=",DoubleToString(rates[i].close,_Digits),
            " V=",(long)rates[i].tick_volume);
     }
  }
