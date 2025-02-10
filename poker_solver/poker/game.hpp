#ifndef MUSCLE_COMPUTING_GAME_H
#define MUSCLE_COMPUTING_GAME_H

#include <vector>
#include <algorithm>
#include <QObject>

#include "cards.hpp"
#include "player.hpp"

enum class Street
{
    PRE_FLOP = 1,
    FLOP,
    TURN,
    RIVER
};

class game: public QObject
{
    Q_OBJECT
    Q_PROPERTY(int game_pot READ get_pot NOTIFY potChanged)
    int small_blind = 1;
    int big_blind = 3;
    int button = 0;
    bool in_progress = false;
    Street street;
    card_deck deck;
    std::vector<card> get_hand_vector(int);

public:
    explicit game(QObject *parent = 0) : QObject(parent) {}
    bool is_game_in_progress();
    void join_table(player player);
    int players_count();
    // TODO: Make this private,
    // when you figure out how to test better.
    int pot = 0;
    std::vector<card> flop;
    card turn;
    card river;
    std::vector<player> table;
    int get_pot() { return pot;}
    void start();
    void collect_blinds();
    void take_bets();
    void deal_hold_cards();
    void deal_flop();
    void deal_turn();
    void deal_river();
    void decide_the_payout();

    void do_payouts();
    void switch_button();

    std::string evaluator(std::vector<card>);
signals:
    void potChanged();
};
#endif // MUSCLE_COMPUTING_GAME_H