#ifndef TEXAS_HOLDEM_GYM_GAME_H
#define TEXAS_HOLDEM_GYM_GAME_H

#include <array>
#include <random>
#include <memory>
#include <vector>

#include <QObject>
#include <QtGlobal>
#include <QString>
#include <QStringList>
#include <QVariant>
#include <QVariantMap>

#include "bankroll_tracker.hpp"
#include "seat_manager.hpp"
#include "bot.hpp"
#include "cards.hpp"
#include "player.hpp"
#include "range_matrix.hpp"

enum class Street
{
    PRE_FLOP = 1,
    FLOP,
    TURN,
    RIVER
};

struct SeatBot
{
    /// Preflop weights: call (limp/call), raise (incl. 3-bet intent), open/lead (first-in aggression).
    RangeMatrix range_call;
    RangeMatrix range_raise;
    RangeMatrix range_bet;
    BotStrategy strategy = BotStrategy::AlwaysCall;
    /// Tunable engine knobs (defaults from `params_for(strategy)` when preset changes).
    BotParams params{};
};

class GamePersistence;
class HumanDecisionController;

/// No-limit Texas Hold'em: two hole cards, flop–turn–river, blinds and betting rounds per street.
class game : public QObject
{
    Q_OBJECT
    friend class GamePersistence;
    friend class BankrollTracker;
    friend class HumanDecisionController;
    friend class SeatManager;

public:
    static constexpr int kMaxPlayers = 6;

private:
    static constexpr int kHumanSeat = 0; // seat 0 = human; 1–5 = bots

    int small_blind = 1;
    int big_blind = 3;
    /// Max chips on the table per buy-in, expressed as big-blind multiples (× BB chips).
    int max_on_table_bb_ = 100;
    int street_bet_ = 9;
    int button = 0;
    bool in_progress = false;
    Street street = Street::PRE_FLOP;
    card_deck deck;
    int starting_stack_ = 100;
    bool ui_showdown_ = false;
    /// True after `deal_hold_cards()`; false after `clear_for_new_hand()`.
    /// Prevents `sync_ui()` from sending stale card paths (which kept QML flipped-state stuck).
    bool cards_dealt_ = false;
    /// Incremented each `clear_for_new_hand()` so QML can reset hole-card visuals between hands.
    int hand_seq_ = 0;

    std::array<SeatBot, kMaxPlayers> seat_cfg_{};
    std::array<bool, kMaxPlayers> in_hand_{};
    /// Chips each seat has put in the current betting round (incl. blinds preflop).
    std::array<int, kMaxPlayers> street_contrib_{};
    /// Total chips each seat has put into the pot this hand (all streets; incl. blinds). Used for side pots.
    std::array<int, kMaxPlayers> hand_contrib_{};
    /// Short UI label for the last action this street (Call / Raise / Check / Fold / blinds).
    std::array<QString, kMaxPlayers> seat_street_action_label_{};
    int last_raise_increment_ = 0;
    bool bb_preflop_option_open_ = false;
    std::mt19937 rng_{std::random_device{}()};

    std::vector<card> get_hand_vector(int idx) const;
    std::vector<card> cards_for_strength(int seat, Street st) const;

    std::vector<int> action_order(Street st) const;
    int count_active() const;
    /// True if every seat still `in_hand_` has no chips behind (all-in or blind-only — no further betting).
    bool everyone_in_hand_is_all_in() const;
    /// Heads-up: one player is all-in and the other still has chips — no further betting; run the board out
    /// (`run_street_betting` applies this from the flop onward so preflop can still complete).
    bool heads_up_one_all_in_other_has_chips() const;
    int max_street_contrib() const;
    void init_preflop_street_contrib();
    void reset_postflop_street_contrib();
    bool run_street_betting(Street st);
    bool handle_forced_response(int seat, Street st, int current_max);
    bool handle_postflop_check_or_bet(Street st);
    bool handle_bb_preflop_option();
    void award_pot_to_seat(int seat);
    void award_pot_to_last_standing();
    /// Adds chips to `pot` and `hand_contrib_` for this seat (must match chips taken from `stack`).
    void add_chips_to_pot(int seat, int chips);
    void note_river_aggressor(Street st, int seat);

public:
    explicit game(QObject *parent = nullptr);
    ~game() override;

    Q_INVOKABLE void setRootObject(QObject *root);

    int pot = 0;
    card turn;
    card river;
    std::vector<card> flop;
    std::vector<player> table;

    void start();
    /// Invoked from QML (avoid name clash with QML/Qt `start`); runs one full hand.
    Q_INVOKABLE void beginNewHand();
    bool is_game_in_progress() const;
    /// Adds a player if stack is in `(10×BB, maxBuyInChips()]` — training-app stake model, not a generic engine API.
    void join_table(player player);
    int players_count() const;
    void collect_blinds();
    /// Unit-test helper: every seat posts `street_bet_` (not used by live `start()`).
    void take_bets_for_testing();
    void deal_hold_cards();
    void deal_flop();
    void deal_turn();
    void deal_river();
    void decide_the_payout();
    std::string evaluator(const std::vector<card> &);

    Q_INVOKABLE void configure(int smallBlind, int bigBlind, int streetBet, int startStack);
    /// Last configured stakes (for setup UI after load).
    Q_INVOKABLE int configuredSmallBlind() const { return small_blind; }
    Q_INVOKABLE int configuredBigBlind() const { return big_blind; }
    Q_INVOKABLE int configuredStreetBet() const { return street_bet_; }
    Q_INVOKABLE int configuredStartStack() const { return starting_stack_; }
    /// Table rule: max on-table chips per buy-in = `configuredMaxOnTableBb() × big blind` (chips).
    Q_INVOKABLE int configuredMaxOnTableBb() const { return max_on_table_bb_; }
    Q_INVOKABLE void setMaxOnTableBb(int maxBb);
    /// Maximum chips a seat may bring to the table per buy-in / apply (`configuredMaxOnTableBb() ×` big blind).
    Q_INVOKABLE int maxBuyInChips() const;
    /// Table stack + off-table wallet for `seat` (pending total if edited mid-hand).
    Q_INVOKABLE int seatBankrollTotal(int seat) const;
    /// Per-seat buy-in (target stack; capped at `maxBuyInChips()`; excess stays off-table as bankroll).
    Q_INVOKABLE int seatBuyIn(int seat) const;
    Q_INVOKABLE void setSeatBuyIn(int seat, int chips);
    /// Push `seat_buy_in_` to table stacks + off-table bankroll (no-op if a hand is in progress).
    Q_INVOKABLE void applySeatBuyInsToStacks();
    /// True when buy-ins were edited during a hand; call `applySeatBuyInsToStacks()` when idle.
    Q_INVOKABLE bool pendingSeatBuyInsApply() const { return seat_mgr_.pendingSeatBuyInsApply(); }
    /// True when total bankroll was set during a hand; applied at the next `beginNewHand()`.
    Q_INVOKABLE bool pendingSeatBankrollApply() const;
    Q_INVOKABLE bool gameInProgress() const { return in_progress; }
    Q_INVOKABLE int seatStrategyIndex(int seat) const;
    Q_INVOKABLE void loadPersistedSettings();
    Q_INVOKABLE void savePersistedSettings() const;
    /// Fills only keys missing from the store (startup seed). Does **not** overwrite existing values — unlike `savePersistedSettings`.
    void seedMissingPersistedSettings() const;

    Q_INVOKABLE void setSeatStrategy(int seat, int strategyIndex);
    /// Current strategy parameters for `seat` (exponents + aggression bonuses / tight multipliers).
    Q_INVOKABLE QVariantMap seatStrategyParams(int seat) const;
    Q_INVOKABLE void setSeatStrategyParams(int seat, QVariantMap params);
    /// Preset 13×13 weights for a bot archetype (for charts / reference). `layer`: 0=call, 1=raise, 2=bet (presets match all layers).
    Q_INVOKABLE QVariantList getPresetRangeGrid(int strategyIndex, int layer = 0) const;
    /// Full strategy text: exponents, default chart, aggression notes.
    Q_INVOKABLE QString getStrategySummary(int strategyIndex) const;
    /// Short labels for setup UI, one per `BotStrategy` in enum order (`bot_strategy_name`).
    Q_INVOKABLE QStringList strategyDisplayNames() const;
    /// Parse range text into layer 0=call, 1=raise, 2=bet (open/lead).
    Q_INVOKABLE bool applySeatRangeText(int seat, const QString &text, int layer = 0);
    Q_INVOKABLE void setRangeCell(int seat, int row, int col, double w, int layer = 0);
    Q_INVOKABLE QVariantList getRangeGrid(int seat, int layer = 0) const;
    Q_INVOKABLE QString exportSeatRangeText(int seat, int layer = 0) const;
    Q_INVOKABLE int getStreetBet() const { return street_bet_; }
    Q_INVOKABLE void resetSeatRangeFull(int seat);
    /// Seats 1–5 only: when false, that bot sits out (not dealt in) until re-enabled.
    Q_INVOKABLE void setSeatParticipating(int seat, bool participating);
    Q_INVOKABLE bool seatParticipating(int seat) const;
    /// Longer pause between bot actions (UI pacing). Exposed as a QML property (`botSlowActions`, not `botSlowActions()`).
    Q_PROPERTY(bool botSlowActions READ botSlowActions WRITE setBotSlowActions NOTIFY botSlowActionsChanged)
    Q_INVOKABLE void setBotSlowActions(bool enabled);
    bool botSlowActions() const;
    /// Pause after a hand ends (showdown / winner lines) before `beginNewHand()` when auto-deal is on. Clamped 500 ms–60 s.
    Q_PROPERTY(int winningHandShowMs READ winningHandShowMs WRITE setWinningHandShowMs NOTIFY winningHandShowMsChanged)
    Q_INVOKABLE void setWinningHandShowMs(int ms);
    int winningHandShowMs() const;
    /// Pause between bot actions when “Slow down bots!” is on. Clamped 1–30 s (replaces former ~2.4 s hardcode).
    Q_PROPERTY(int botDecisionDelaySec READ botDecisionDelaySec WRITE setBotDecisionDelaySec NOTIFY botDecisionDelaySecChanged)
    Q_INVOKABLE void setBotDecisionDelaySec(int sec);
    int botDecisionDelaySec() const;
    /// When false, skips the fixed delay after each bot action (default true; set false in unit tests).
    Q_INVOKABLE void setBotActionDelayEnabled(bool enabled);
    Q_INVOKABLE bool botActionDelayEnabled() const { return bot_action_delay_enabled_; }
    /// When false, seat 0 uses the same strategy/range bot logic as seats 1–5 (no on-felt decision UI).
    /// When true (default), the human acts through the HUD. Unit tests may disable for scripted runs.
    Q_PROPERTY(bool interactiveHuman READ interactiveHuman WRITE setInteractiveHuman NOTIFY interactiveHumanChanged)
    Q_INVOKABLE void setInteractiveHuman(bool enabled);
    bool interactiveHuman() const { return interactive_human_; }
    /// When true, seat 0 skips upcoming hands (watch bots). Enabling while you must act folds/checks
    /// through the current decision (fold facing a bet; fold when checked to; check BB option).
    Q_INVOKABLE void setHumanSitOut(bool enabled);
    Q_INVOKABLE bool humanSitOut() const { return human_sitting_out_; }
    /// When false, a completed hand does not automatically start the next (tests).
    Q_INVOKABLE void setAutoHandLoop(bool enabled);
    Q_INVOKABLE bool autoHandLoop() const { return auto_hand_loop_; }
    /// Facing a raise: 0=fold, 1=call, 2=raise; raiseChips = total chips to add from stack this action (min raise to all-in).
    Q_INVOKABLE void submitFacingAction(int action, int raiseChips);
    /// No wager yet: check=true to check; else bet `betChips` from stack (>= 1 chip, up to stack).
    Q_INVOKABLE void submitCheckOrBet(bool check, int betChips);
    /// BB preflop option: add `chipsToAdd` from stack (>= min raise increment, up to stack).
    Q_INVOKABLE void submitBbPreflopRaise(int chipsToAdd);
    /// Fold when checked to with no raise yet; mucks the hand.
    Q_INVOKABLE void submitFoldFromCheck();

    /// Increments on bankroll snapshots and on `notifySessionStatsChanged()` — binds QML to refresh invokables.
    Q_PROPERTY(int statsSeq READ statsSeq NOTIFY sessionStatsChanged)
    int statsSeq() const { return bankroll_tracker_.statsSeq(); }
    /// Bumped when any seat range matrix changes so QML range grids can refresh (`getRangeGrid` has no NOTIFY).
    Q_PROPERTY(int rangeRevision READ rangeRevision NOTIFY rangeRevisionChanged)
    int rangeRevision() const { return range_revision_; }
    /// No new chart point: bumps `statsSeq` so Stats / buy-in lines refresh (e.g. after `setSeatBuyIn`).
    Q_INVOKABLE void notifySessionStatsChanged();

    /// Leaderboard row maps: `seat`, `stack`, `rank`, `profit` (vs session baseline).
    Q_INVOKABLE QVariantList seatRankings() const;
    /// Stack after each recorded snapshot for `seat` (same length for all seats).
    Q_INVOKABLE QVariantList bankrollSeries(int seat) const;
    Q_INVOKABLE int bankrollSnapshotCount() const;
    /// Wall-clock ms since epoch for each bankroll snapshot (same length as `bankrollSeries`).
    Q_INVOKABLE QVariantList bankrollSnapshotTimesMs() const;
    Q_INVOKABLE int sessionBaselineStack(int seat) const;
    /// Clear history and re-baseline from current stacks (one snapshot).
    Q_INVOKABLE void resetBankrollSession();
    /// Sets total chips for `seat` (table stack up to `maxBuyInChips()`, rest off-table; buy-in = on-table amount).
    /// When a hand is in progress, the change is deferred until the next hand (like `setSeatBuyIn`).
    Q_INVOKABLE void setSeatBankrollTotal(int seat, int totalChips);
    /// Apply any deferred `setSeatBankrollTotal` edits (no-op if idle or nothing pending).
    Q_INVOKABLE void applyPendingBankrollTotals();

    /// Blind seats and first actor seats for the current `button` / `in_hand_` state (tests / diagnostics).
    /// Clockwise table order uses `(seat + n - 1) % n` in index space (see `first_in_hand_after`).
    Q_INVOKABLE QVariantMap bettingAnchors() const;
    /// Effective preflop “bet to match” after blinds (`max(SB posted, BB posted)`); 0 when idle / before init.
    Q_INVOKABLE int preflopBlindLevel() const { return preflop_blind_level_; }

    /// Off-table portion of bankroll, available for rebuy (starts at 0 after apply; persistence may restore a reserve).
    Q_INVOKABLE int seatWallet(int seat) const;
    /// Seat 0 buy-in (× BB, capped) when “Play as bot” is on — for UI checks vs `seatBankrollTotal(0)`.
    Q_INVOKABLE int autoplayBuyInChips() const;
    /// `stack == 0`, hand idle, and off-table bankroll has at least one full buy-in for that seat (`seatBuyIn(seat)`).
    Q_INVOKABLE bool canBuyBackIn(int seat) const;
    /// Move one `seatBuyIn(seat)` from off-table bankroll to stack. No-op if not allowed.
    Q_INVOKABLE bool tryBuyBackIn(int seat);

signals:
    void pot_changed();
    void sessionStatsChanged();
    void rangeRevisionChanged();
    void interactiveHumanChanged();
    void botSlowActionsChanged();
    void winningHandShowMsChanged();
    void botDecisionDelaySecChanged();

public slots:
    void buttonClicked(QString button);

private slots:
    void on_pot_changed();

private:
    QObject *m_root = nullptr;
    bool interactive_human_ = true;
    bool human_sitting_out_ = false;
    int sb_seat_ = -1;
    int bb_seat_ = -1;
    /// After blinds: `max(actual SB posted, actual BB posted)` — used for BB option / “raised over blinds” (nominal `big_blind` is wrong when blinds are short).
    int preflop_blind_level_ = 0;
    int acting_seat_ = -1;
    bool auto_hand_loop_ = true;
    bool bot_slow_actions_ = false;
    /// `bot_action_pause` duration when `bot_slow_actions_` (seconds; applied as ms in the loop).
    int bot_decision_delay_sec_ = 2;
    /// `schedule_next_hand_if_idle`: delay before auto `beginNewHand()` (default 5 s).
    int winning_hand_show_ms_ = 5000;
    /// When false, `bot_action_pause` is a no-op (keeps CI fast; UI keeps default true).
    bool bot_action_delay_enabled_ = true;
    /// Bumped when call/raise/bet range weights change (text parse, cell edit, reset full).
    int range_revision_ = 0;
    /// While `loadPersistedSettings()` runs, skip auto-save in mutators (order matters: strategy then range text).
    bool suppress_persist_ = false;
    /// Set true only after `loadPersistedSettings()` finishes applying DB state — blocks saves until then.
    bool persist_loaded_ = false;
    /// QML `statusText`: last pot result; kept visible until the next hand awards the pot.
    QString last_hand_result_message_{};
    /// QML `resultBannerCardAssets`: best 5-card combination (`qrc:/assets/cards/` filenames).
    QStringList last_hand_result_card_assets_{};
    SeatManager seat_mgr_;
    BankrollTracker bankroll_tracker_;
    std::unique_ptr<HumanDecisionController> human_decision_ctrl_;
    std::unique_ptr<GamePersistence> persistence_;

    /// Minimum chips for a legal raise: `max(big blind, last raise increment)`.
    static int min_raise_increment_chips(int big_blind, int last_raise_increment);
    void schedule_next_hand_if_idle();
    void complete_hand_idle();
    void configureImpl(int smallBlind, int bigBlind, int streetBet, int startStack, bool resetBankrollOnStackApply);
    /// Stack target for rebuy / apply: seat 0 uses `seat_buy_in_` when interactive; otherwise `buy_in_bb ×` BB (capped).
    int effectiveSeatBuyInChips(int seat) const;
    void bot_action_pause();
    /// Postflop: no open bet — record a check and pause (mirrors human `Check` label).
    void bot_record_postflop_check(int seat);
    void clear_for_new_hand();
    void clear_street_action_labels();
    void set_seat_street_action(int seat, const QString &label);
    void set_hand_result_status(const QString &msg, const QStringList &cardAssets = {});
    QString board_compact_for_result() const;
    /// One line per seat with chips won: `Name wins $N holding … on … with …` (hand name from `winning_hand_label`).
    QString format_showdown_payout_lines_from_gains(const std::array<int, kMaxPlayers> &stack_gain, int players_n) const;
    int banner_seat_from_showdown_gains(const std::array<int, kMaxPlayers> &stack_gain, int players_n) const;
    /// Last player wins the pot because everyone else folded (no showdown).
    QString fold_win_status_line(int seat, int pot_chips) const;
    /// Human-readable winning holding from holes + board at `street` (e.g. “Two pair, Q and 10”).
    QString winning_hand_label(int seat) const;
    QStringList result_banner_card_assets_for_seat(int seat) const;
    /// First seat **clockwise** from `prev_seat` that is still in the hand (-1 if none). Implemented as
    /// `(prev_seat + n - 1) % n` in seat index (see `game-in-code.md`).
    int first_in_hand_after(int prev_seat) const;
    /// In rotation for the button: has chips, human not sitting out, bots not opted out.
    bool seat_eligible_for_positions(int seat) const;
    /// Next **clockwise** eligible seat for dealer rotation (`(from + n - 1) % n` scan).
    int next_seat_in_position_pool(int from) const;
    void ensure_button_on_eligible_seat();
    void compute_blind_seats(int &sb, int &bb) const;
    void do_payouts();
    void switch_button();
    QString human_hand_line_for_ui() const;
    /// Two hole cards, e.g. `"Ah Kd"`.
    QString hole_cards_display(int seat) const;
    void sync_ui();
    void flush_ui();
};

#endif // TEXAS_HOLDEM_GYM_GAME_H
