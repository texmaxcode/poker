#ifndef MUSCLE_COMPUTING_PLAYER_H
#define MUSCLE_COMPUTING_PLAYER_H

#include "cards.hpp"

class player
{
public:
    card first_card;
    card second_card;
    int stack = 0;

    player() = default;
    player(card first_card, card second_card) : first_card(first_card), second_card(second_card) {}
    void take_hold_cards(card first_card, card second_card);
    int pay(int amount);
    int take_from_stack(int amount);
    void reset_stack(int chips);
};

#endif
