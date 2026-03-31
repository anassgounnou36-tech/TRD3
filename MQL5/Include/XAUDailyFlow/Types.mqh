#ifndef XAUDAILYFLOW_TYPES_MQH
#define XAUDAILYFLOW_TYPES_MQH

enum XDFRegime
  {
   REGIME_TREND_CONTINUATION = 0,
   REGIME_MEAN_REVERSION     = 1,
   REGIME_MIXED              = 2,
   REGIME_NO_TRADE           = 3
  };

enum XDFSetupFamily
  {
   SETUP_NONE             = 0,
   SETUP_ORB_CONTINUATION = 1,
   SETUP_MEAN_REVERSION   = 2
  };

enum XDFSessionId
  {
   SESSION_NONE   = -1,
   SESSION_LONDON = 0,
   SESSION_NEWYORK= 1
  };

struct XDFSessionConfig
  {
   int               start_hour;
   int               start_minute;
   int               or_minutes;
   int               trade_minutes;
   XDFSessionId      id;
   string            name;
  };

struct XDFSessionState
  {
   datetime          day_anchor;
   datetime          session_start;
   datetime          or_end;
   datetime          trade_end;
   bool              active;
   bool              or_complete;
   bool              touched_above;
   bool              touched_below;
  };

struct XDFOpeningRange
  {
   double            high;
   double            low;
   double            midpoint;
   double            width;
   bool              valid;
  };

struct XDFSignal
  {
   bool              valid;
   XDFSetupFamily    family;
   int               direction; // +1 buy, -1 sell
   string            reason;
   double            entry;
   double            stop;
   double            tp_hint;
  };

struct XDFScoreBreakdown
  {
   int               range_quality;
   int               context_quality;
   int               trigger_quality;
   int               execution_quality;
   int               vwap_quality;
   int               noise_penalty;
   int               total;
  };

struct XDFSymbolSpecs
  {
   string            symbol;
   int               digits;
   double            point;
   double            tick_size;
   double            tick_value;
   double            min_lot;
   double            max_lot;
   double            lot_step;
   int               stops_level_points;
   int               freeze_level_points;
  };

struct XDFPositionState
  {
   bool              has_position;
   ulong             ticket;
   int               direction;
   double            entry;
   double            stop;
   double            take_profit;
   datetime          opened_at;
   bool              moved_to_breakeven;
   bool              tp1_seen;
  };

#endif
