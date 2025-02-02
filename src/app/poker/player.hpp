#ifndef MUSCLE_COMPUTING_PLAYER_H
#define MUSCLE_COMPUTING_PLAYER_H

#include "cards.hpp"

class player
{
public:
  card first_card;
  card second_card;
  player(card first_card, card second_card): first_card(first_card), second_card(second_card) {};
  void take_hold_cards(card first_card, card second_card);
};

#endif // MUSCLE_COMPUTING_PLAYER_H