#ifndef MUSCLE_COMPUTING_GAME_H
#define MUSCLE_COMPUTING_GAME_H

#include <vector>
#include <algorithm>
#include <QObject>
#include <QVariant>
#include <QtQuick/QQuickItem>

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
    Q_PROPERTY(int game_pot READ get_pot NOTIFY pot_changed)
    int small_blind = 1;
    int big_blind = 3;
    int button = 0;
    bool in_progress = false;
    Street street;
    card_deck deck;
    std::vector<card> get_hand_vector(int);

public:
    game(QObject *parent =0);
    ~game();
    void setRootObject(QQuickItem* root);

    // TODO: Make this private,
    // when you figure out how to test better.
    int pot = 0;
    std::vector<card> flop;
    card turn;
    card river;
    std::vector<player> table;

    bool is_game_in_progress();
    void join_table(player player);
    int players_count();

    int get_pot() { return pot;}
    Q_INVOKABLE void start();
    void collect_blinds();
    void take_bets();
    void deal_hold_cards();
    void deal_flop();
    void deal_turn();
    void deal_river();
    void decide_the_payout();
    std::string evaluator(std::vector<card>);

    /*
    void do_payouts();
    void switch_button();
    */

signals:
    void pot_changed();

private slots:
    void onPotChanged();

private:
    QQuickItem* m_root;
    void clearAll();

};

#endif // MUSCLE_COMPUTING_GAME_H