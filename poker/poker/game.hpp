#ifndef MUSCLE_COMPUTING_GAME_H
#define MUSCLE_COMPUTING_GAME_H

#include <array>
#include <random>
#include <vector>

#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariant>

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
    RangeMatrix range;
    BotStrategy strategy = BotStrategy::AlwaysCall;
};

/// No-limit Texas Hold'em: two hole cards, flop–turn–river, blinds and betting rounds per street.
class game : public QObject
{
    Q_OBJECT
    static constexpr int kMaxPlayers = 6;
    static constexpr int kHumanSeat = 0; // seat 0 = human; 1–5 = bots

    int small_blind = 1;
    int big_blind = 3;
    int street_bet_ = 9;
    int button = 0;
    bool in_progress = false;
    Street street = Street::PRE_FLOP;
    card_deck deck;
    int starting_stack_ = 100;
    bool ui_showdown_ = false;

    std::array<SeatBot, kMaxPlayers> seat_cfg_{};
    std::array<bool, kMaxPlayers> in_hand_{};
    /// Chips each seat has put in the current betting round (incl. blinds preflop).
    std::array<int, kMaxPlayers> street_contrib_{};
    int last_raise_increment_ = 0;
    bool bb_preflop_option_open_ = false;
    /// Last seat to bet or raise on the river (for showdown order per standard rules).
    int river_last_aggressor_ = -1;
    bool river_had_bet_or_raise_ = false;
    std::mt19937 rng_{std::random_device{}()};

    std::vector<card> get_hand_vector(int idx) const;
    std::vector<card> cards_for_strength(int seat, Street st) const;

    std::vector<int> action_order(Street st) const;
    int count_active() const;
    int max_street_contrib() const;
    void init_preflop_street_contrib();
    void reset_postflop_street_contrib();
    bool run_street_betting(Street st);
    bool handle_forced_response(int seat, Street st, int current_max);
    bool handle_postflop_check_or_bet(Street st);
    bool handle_bb_preflop_option();
    void award_pot_to_seat(int seat);
    void award_pot_to_last_standing();
    void note_river_aggressor(Street st, int seat);
    int first_active_clockwise_from_button() const;

public:
    explicit game(QObject *parent = nullptr);
    ~game() override = default;

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
    void join_table(player player);
    int players_count() const;
    void collect_blinds();
    void take_bets();
    void deal_hold_cards();
    void deal_flop();
    void deal_turn();
    void deal_river();
    void decide_the_payout();
    std::string evaluator(const std::vector<card> &);

    Q_INVOKABLE void configure(int smallBlind, int bigBlind, int streetBet, int startStack);
    Q_INVOKABLE void setSeatStrategy(int seat, int strategyIndex);
    /// Preset 13×13 weights for a bot archetype (for charts / reference).
    Q_INVOKABLE QVariantList getPresetRangeGrid(int strategyIndex) const;
    /// Full strategy text: exponents, default chart, aggression notes.
    Q_INVOKABLE QString getStrategySummary(int strategyIndex) const;
    Q_INVOKABLE bool applySeatRangeText(int seat, const QString &text);
    Q_INVOKABLE void setRangeCell(int seat, int row, int col, double w);
    Q_INVOKABLE QVariantList getRangeGrid(int seat) const;
    Q_INVOKABLE QString exportSeatRangeText(int seat) const;
    Q_INVOKABLE int getStreetBet() const { return street_bet_; }
    Q_INVOKABLE void resetSeatRangeFull(int seat);
    /// When false (e.g. unit tests), seat 0 auto-acts without UI/timer.
    Q_INVOKABLE void setInteractiveHuman(bool enabled);
    Q_INVOKABLE bool interactiveHuman() const { return interactive_human_; }
    /// When true, seat 0 skips the next hands (watch bots). Takes effect when a new hand starts.
    Q_INVOKABLE void setHumanSitOut(bool enabled);
    Q_INVOKABLE bool humanSitOut() const { return human_sitting_out_; }
    /// When false, a completed hand does not automatically start the next (tests).
    Q_INVOKABLE void setAutoHandLoop(bool enabled);
    Q_INVOKABLE bool autoHandLoop() const { return auto_hand_loop_; }
    /// Facing a bet: 0=fold, 1=call, 2=raise; raiseChips = total chips to add from stack this action (min raise to all-in).
    Q_INVOKABLE void submitFacingAction(int action, int raiseChips);
    /// No bet yet: check=true to check; else bet betChips (>= street bet, up to stack).
    Q_INVOKABLE void submitCheckOrBet(bool check, int betChips);

signals:
    void pot_changed();
    void ui_state_changed();
    void humanDecisionFinished();
    void humanCheckFinished();
    void humanBbPreflopFinished();

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
    int acting_seat_ = -1;
    int decision_seconds_left_ = 0;
    bool waiting_for_human_ = false;
    bool waiting_for_human_check_ = false;
    /// While facing a bet: 0 = fold, 1 = call, 2 = raise (amount in human_facing_raise_chips_).
    int human_facing_action_ = -1;
    int human_facing_raise_chips_ = 0;
    bool human_opened_bet_from_check_ = false;
    bool waiting_for_human_bb_preflop_ = false;
    bool human_bb_preflop_raised_ = false;
    bool human_more_time_available_ = false;
    bool auto_hand_loop_ = true;
    int pending_human_need_ = 0;
    int pending_human_raise_inc_ = 0;
    QTimer human_decision_tick_;
    QTimer human_decision_deadline_;

    void wait_for_human_need(int need_chips, Street st, int min_raise_increment);
    bool wait_for_human_check_or_bet(Street st);
    bool wait_for_human_bb_preflop();
    void finish_human_check(bool check, int bet_chips);
    void finish_human_bb_preflop(bool raise);
    void requestMoreTime();
    void schedule_next_hand_if_idle();
    void clear_for_new_hand();
    /// First seat clockwise after `prev_seat` that is still in the hand (-1 if none).
    int first_in_hand_after(int prev_seat) const;
    void compute_blind_seats(int &sb, int &bb) const;
    void do_payouts();
    void switch_button();
    void sync_ui();
    void flush_ui();
};

#endif
