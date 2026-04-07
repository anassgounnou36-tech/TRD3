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
   BLOCKER_NO_SETUP            = 15,
   BLOCKER_PAYOFF              = 16
  };

enum XDFSessionId
  {
   SESSION_NONE   = -1,
   SESSION_LONDON = 0,
   SESSION_NEWYORK= 1
  };

const double XDF_EXPECTED_SLIPPAGE_MIN_POINTS=2.0;
const double XDF_EXPECTED_SLIPPAGE_SPREAD_FACTOR=0.15;
const double XDF_EXPECTED_SLIPPAGE_CAP_POINTS=8.0;
const int XDF_ORB_SECONDARY_ALLOW_MIN_SCORE=65;
const double XDF_ORB_WEAK_SUBTYPE_MIN_GROSS_RR=1.15;
const double XDF_ORB_WEAK_SUBTYPE_NET_TARGET_SPREAD_FACTOR=1.5;
const double XDF_ORB_DIRECT_BREAK_MIN_GROSS_RR=1.20;

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
   double            stop_points;
   double            target_points;
   double            atr_points;
   double            or_width_points;
   double            spread_points;
   double            slip_points;
   double            gross_rr;
   double            net_target_points;
   double            net_rr;
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
   double            expected_slippage_points;
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
   string            selection_reason;
   string            mr_block_reason;
   string            mr_override_reason;
   string            orb_block_reason;
   string            orb_override_reason;
   string            primary_reject_reason;
   bool              fallback_attempted;
   bool              fallback_accepted;
   string            fallback_reason;
   bool              eligible_orb;
   bool              eligible_mr;
   int               orb_score_raw;
   int               mr_score_raw;
   int               orb_score_final;
   int               mr_score_final;
   bool              mr_penalty_applied;
   bool              mr_exceptional_allowed;
   bool              or_width_secondary_allow;
   double            or_width_primary_limit;
   double            or_width_secondary_limit;
   int               or_width_score_penalty;
   double            stop_dist_points;
   double            target_dist_points;
   double            spread_points;
   double            expected_slip_points;
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

struct XDFGeometryMetrics
  {
   double            gross_rr;
   double            net_target_points;
   double            net_rr;
  };

// Unified minimum net-R policy used by source, decision, and execution gates.
// Returns family/subtype/regime-specific minimum acceptable net risk-reward ratio.
double XDF_MinNetRRForFamilyRegimeSubtype(const XDFSetupFamily family,const string subtype,const XDFRegime regime)
  {
   if(family==SETUP_ORB_CONTINUATION)
     {
      double direct_break_uplift=(subtype=="ORB_DIRECT_BREAK"?0.08:0.0);
      if(regime==REGIME_TREND_CONTINUATION)
         return(1.10+direct_break_uplift);
      if(regime==REGIME_MIXED)
         return(1.15+direct_break_uplift);
      if(regime==REGIME_MEAN_REVERSION)
         return(1.20+direct_break_uplift);
      return(1.15+direct_break_uplift);
     }
   if(family==SETUP_MEAN_REVERSION)
     {
      if(subtype=="MR_IMMEDIATE_SWEEP_RECLAIM" || subtype=="MR_DELAYED_RECLAIM_WINDOW")
         return(1.10);
      return(1.05);
     }
   return(0.0);
  }

double XDF_MinStopFloorPtsForFamily(const XDFSetupFamily family,const double atr_points,const double spread_points,const double slip_points)
  {
   if(family==SETUP_ORB_CONTINUATION)
      return(MathMax(0.30*atr_points,1.60*spread_points+2.0*slip_points));
   if(family==SETUP_MEAN_REVERSION)
      return(MathMax(0.35*atr_points,1.80*spread_points+2.0*slip_points));
   return(0.0);
  }

double XDF_MaxStopCapPtsForFamily(const XDFSetupFamily family,const double atr_points,const double or_width_points)
  {
   if(family==SETUP_ORB_CONTINUATION)
     {
      double width_component=(or_width_points>0.0?0.75*or_width_points+0.10*atr_points:0.95*atr_points);
      return(MathMin(0.95*atr_points,width_component));
     }
   if(family==SETUP_MEAN_REVERSION)
      return(0.85*atr_points);
   return(1.0e9);
  }

// Single source of truth for geometry validation across source, decision, selected-candidate,
// and pre-send execution checks. Populates computed metrics and sets reason on failure.
bool XDF_PassesGeometryPolicy(const XDFSetupFamily family,
                              const string subtype,
                              const XDFRegime regime,
                              const double stop_points,
                              const double target_points,
                              const double spread_points,
                              const double slip_points,
                              const double atr_points,
                              const double or_width_points,
                              XDFGeometryMetrics &metrics,
                              string &reason)
  {
   metrics.gross_rr=(stop_points>0.0?target_points/stop_points:0.0);
   metrics.net_target_points=target_points-spread_points-slip_points;
   metrics.net_rr=(stop_points>0.0?metrics.net_target_points/stop_points:0.0);
   reason="";

   if(stop_points<=0.0 || target_points<=0.0 || atr_points<=0.0)
     {
      reason=(family==SETUP_ORB_CONTINUATION?"ORB_GEOMETRY_INVALID_INPUTS":"MR_GEOMETRY_INVALID_INPUTS");
      return(false);
     }

   double stop_floor=XDF_MinStopFloorPtsForFamily(family,atr_points,spread_points,slip_points);
   if(stop_points<stop_floor)
     {
      reason=(family==SETUP_ORB_CONTINUATION?"ORB_GEOMETRY_STOP_TOO_TIGHT":"MR_GEOMETRY_STOP_TOO_TIGHT");
      return(false);
     }

   double stop_cap=XDF_MaxStopCapPtsForFamily(family,atr_points,or_width_points);
   if(stop_points>stop_cap)
     {
      reason=(family==SETUP_ORB_CONTINUATION?"ORB_GEOMETRY_STOP_TOO_WIDE":"MR_GEOMETRY_STOP_TOO_WIDE");
      return(false);
     }

   if(target_points<=stop_points || metrics.net_target_points<=0.0)
     {
      reason=(family==SETUP_ORB_CONTINUATION?"ORB_GEOMETRY_COST_THIN":"MR_GEOMETRY_COST_THIN");
      return(false);
     }

   double min_net_rr=XDF_MinNetRRForFamilyRegimeSubtype(family,subtype,regime);
   if(metrics.net_rr<min_net_rr)
     {
      reason=(family==SETUP_ORB_CONTINUATION?"ORB_GEOMETRY_NET_R_TOO_LOW":"MR_GEOMETRY_NET_R_TOO_LOW");
      return(false);
     }

   if(family==SETUP_ORB_CONTINUATION)
     {
      if(metrics.net_target_points<=spread_points)
        {
         reason="ORB_GEOMETRY_COST_THIN";
         return(false);
        }
      if((subtype=="ORB_DIRECT_BREAK" || subtype=="ORB_BREAK_PAUSE_CONTINUE") &&
         (metrics.gross_rr<XDF_ORB_WEAK_SUBTYPE_MIN_GROSS_RR || metrics.net_target_points<XDF_ORB_WEAK_SUBTYPE_NET_TARGET_SPREAD_FACTOR*spread_points))
        {
         reason="ORB_GEOMETRY_COST_THIN";
         return(false);
        }
      if(subtype=="ORB_DIRECT_BREAK" && metrics.gross_rr<XDF_ORB_DIRECT_BREAK_MIN_GROSS_RR)
        {
         reason="ORB_GEOMETRY_COST_THIN";
         return(false);
        }
     }

   return(true);
  }

// v1.5.4 continuation-quality ORB set used for secondary OR-width allowance.
bool XDF_IsORBContinuationQualitySubtype(const string subtype)
  {
   return(subtype=="ORB_DIRECT_BREAK" || subtype=="ORB_TWO_BAR_CONFIRM" || subtype=="ORB_BREAK_RETEST_HOLD" || subtype=="ORB_BREAK_PAUSE_CONTINUE");
  }

bool XDF_IsExceptionalMRSubtype(const string subtype)
  {
   return(subtype=="MR_RECLAIM_THEN_MIDPOINT_CONFIRM" || subtype=="MR_FALSE_BREAK_HOLD_FAIL");
  }

bool XDF_IsRestrictedMRSubtype(const string subtype)
  {
   return(subtype=="MR_IMMEDIATE_SWEEP_RECLAIM" || subtype=="MR_DELAYED_RECLAIM_WINDOW");
  }

#endif
