#include "player.hpp"

void player::take_hold_cards(card f_card, card s_card)
{
    first_card = f_card;
    second_card = s_card;
}

int player::pay(int amount)
{
    const int a = (amount <= stack) ? amount : stack;
    stack -= a;
    return a;
}

int player::take_from_stack(int amount)
{
    if (amount <= 0)
        return 0;
    const int a = (amount <= stack) ? amount : stack;
    stack -= a;
    return a;
}

void player::reset_stack(int chips)
{
    stack = chips;
}