#ifndef TEXAS_HOLDEM_GYM_PLAYER_H
#define TEXAS_HOLDEM_GYM_PLAYER_H

#include "cards.hpp"

class player
{
public:
    card first_card;
    card second_card;
    int stack = 0;

    player() = default;
    void take_hold_cards(card first_card, card second_card);
    int pay(int amount);
    int take_from_stack(int amount);
    void reset_stack(int chips);
};

#endif // TEXAS_HOLDEM_GYM_PLAYER_H
