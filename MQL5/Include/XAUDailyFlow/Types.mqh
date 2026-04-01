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
   SETUP_MEAN_REVERSION   = 2,
   SETUP_BOTH             = 3
  };

enum XDFMgmtState
  {
   MGMT_NONE         = 0,
   MGMT_OPEN         = 1,
   MGMT_TP1_ARMED    = 2,
   MGMT_BE_DONE      = 3,
   MGMT_TRAIL_ACTIVE = 4,
   MGMT_TIME_EXIT    = 5,
   MGMT_COMPLETE     = 6
  };

enum XDFBlocker
  {
   BLOCKER_NONE                = 0,
   BLOCKER_SPREAD              = 1,
   BLOCKER_ATR                 = 2,
   BLOCKER_OR_TOO_NARROW       = 3,
   BLOCKER_OR_TOO_WIDE         = 4,
   BLOCKER_VWAP_EXTENSION      = 5,
   BLOCKER_REGIME              = 6,
   BLOCKER_BIAS                = 7,
   BLOCKER_SCORE               = 8,
   BLOCKER_DAILY_LIMIT         = 9,
   BLOCKER_SESSION_LIMIT       = 10,
   BLOCKER_EXISTING_POSITION   = 11,
   BLOCKER_VOLUME              = 12,
   BLOCKER_EXECUTION_PREFLIGHT = 13,
   BLOCKER_SESSION_CLOSED      = 14,
   BLOCKER_NO_SETUP            = 15
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
   double            trigger_body_ratio;
   double            stop_distance;
   double            target_distance;
   bool              vwap_side_ok;
   int               subtype_quality;
   int               retest_quality;
   int               confirmation_quality;
   int               reclaim_window_quality;
   int               level_hold_quality;
   int               extension_penalty;
   string            subtype;
   string            reason_invalid;
   int               raw_trigger_quality;
   int               raw_context_quality;
   int               raw_extension_penalty;
   int               raw_structure_quality;
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

struct XDFM15Context
  {
   double            fast_ema;
   double            slow_ema;
   double            slope;
   double            atr;
   bool              trend_long;
   bool              trend_short;
   int               trend_alignment; // +1 long / -1 short / 0 neutral
   double            slope_strength;  // |slope| normalized by atr
   double            price_vs_fast;   // price-fast
  };

struct XDFBlockerInfo
  {
   XDFBlocker        code;
   string            message;
  };

struct XDFDecisionContext
  {
   string            symbol;
   XDFOpeningRange   or_data;
   XDFSessionState   session;
   XDFM15Context     m15;
   double            vwap;
   double            mid_price;
   double            atr_m5;
   double            spread_points;
   double            max_spread_points;
   double            min_atr;
   double            max_vwap_distance_points;
   double            point;
   bool              allow_trade;
   int               min_setup_score;
   int               mixed_setup_score;
   int               conflict_override_score;
   int               evaluated_m5_shift;
   datetime          evaluated_m5_time;
   MqlRates          m5_closed[4];
   int               m5_closed_count;
   double            recent_range_price;
   double            vwap_distance_points;
   double            entry_long;
   double            entry_short;
   bool              live_mode;
  };

struct XDFDecision
  {
   bool              has_setup;
   bool              allow_trade;
   XDFRegime         regime;
   string            regime_reason;
   XDFSignal         orb_signal;
   XDFSignal         mr_signal;
   XDFSignal         selected_signal;
   XDFScoreBreakdown selected_score;
   XDFScoreBreakdown orb_score;
   XDFScoreBreakdown mr_score;
   XDFSetupFamily    eligible_family;
   XDFSetupFamily    selected_family;
   XDFBlockerInfo    blocker;
   string            orb_subtype;
   string            mr_subtype;
   string            selected_reject_reason;
   bool              eligible_orb;
   bool              eligible_mr;
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
