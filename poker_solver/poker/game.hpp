#ifndef MUSCLE_COMPUTING_GAME_H
#define MUSCLE_COMPUTING_GAME_H

#include <vector>
#include <algorithm>
#include <QObject>
#include <QString>
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

class game : public QObject
{
    Q_OBJECT
    int small_blind = 1;
    int big_blind = 3;
    int button = 0;
    bool in_progress = false;
    Street street;
    card_deck deck;
    std::vector<card> get_hand_vector(int);

public:
    game(QObject *parent = 0);
    ~game();

    void setRootObject(QObject *root);

    // TODO: Make this private,
    // when you figure out how to test better.
    int pot = 0;
    card turn;
    card river;
    std::vector<card> flop;
    std::vector<player> table;

    Q_INVOKABLE void start();
    bool is_game_in_progress();
    void join_table(player player);
    int players_count();
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

public slots:
    void buttonClicked(QString button);

private slots:
    void on_pot_changed();

private:
    QObject *m_root;
    void clearAll();
};

#endif // MUSCLE_COMPUTING_GAME_H