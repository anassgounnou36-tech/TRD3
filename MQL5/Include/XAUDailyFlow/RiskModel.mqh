#ifndef XAUDAILYFLOW_RISKMODEL_MQH
#define XAUDAILYFLOW_RISKMODEL_MQH

#include <XAUDailyFlow/Types.mqh>

class XDFRiskModel
  {
private:
   double m_day_start_equity;
public:
   XDFRiskModel():m_day_start_equity(0.0){}

   void StartDay(double equity)
     {
      m_day_start_equity=equity;
     }

   bool DailyLossHit(double equity,double max_daily_loss_pct)
     {
      if(m_day_start_equity<=0.0)
         return(false);
      double dd=(m_day_start_equity-equity)/m_day_start_equity*100.0;
      return(dd>=max_daily_loss_pct);
     }

   bool DailyProfitLockHit(double equity,double lock_r,double risk_pct)
     {
      if(m_day_start_equity<=0.0 || lock_r<=0.0 || risk_pct<=0.0)
         return(false);
      double gain_pct=(equity-m_day_start_equity)/m_day_start_equity*100.0;
      return(gain_pct>=lock_r*risk_pct);
     }

   double CalculateLots(const XDFSymbolSpecs &specs,double risk_pct,double stop_distance_price,bool allow_min_lot_override,bool &blocked,bool use_equity=true)
     {
      blocked=false;
      if(stop_distance_price<=0.0 || specs.tick_size<=0.0 || specs.tick_value<=0.0)
        {
         blocked=true;
         return(0.0);
        }

       double base_capital=use_equity ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE);
       if(base_capital<=0.0)
         {
          blocked=true;
          return(0.0);
         }
       double risk_money=base_capital*(risk_pct/100.0);
      double ticks=stop_distance_price/specs.tick_size;
      if(ticks<=0.0)
        {
         blocked=true;
         return(0.0);
        }

      double raw=risk_money/(ticks*specs.tick_value);
      double norm=XDF_NormalizeVolume(specs,raw);

      if(norm<specs.min_lot)
        {
         if(!allow_min_lot_override)
           {
            blocked=true;
            return(0.0);
           }
         norm=specs.min_lot;
      }
      if(norm>specs.max_lot)
         norm=specs.max_lot;
      return(norm);
     }
  };

#endif
