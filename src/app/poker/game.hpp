#ifndef MUSCLE_COMPUTING_GAME_H
#define MUSCLE_COMPUTING_GAME_H

#include <vector>
#include "cards.hpp"
#include "player.hpp"

enum class Street
{
    PRE_FLOP = 1,
    FLOP,
    TURN,
    RIVER
};

class game
{
    int small_blind = 1;
    int big_blind = 3;
    int button = 0;
    bool in_progress = false;
    Street street;
    card_deck deck;

public:
    // TODO: Make this private, 
    // when you figure out how to test better.
    int pot = 0;
    std::vector<player> table;

    bool is_game_in_progress();
    void join_table(player& player);
    int players_count();
    void start();
    //TODO: Make this private
    void collect_blinds();
    void take_bets();
    void deal_hold_cards();
};
#endif // MUSCLE_COMPUTING_GAME_H