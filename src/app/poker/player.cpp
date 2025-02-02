#include "player.hpp"

void player::take_hold_cards(card f_card, card s_card) {
  first_card = f_card;
  second_card = s_card;
}

int player::pay(int amount) {
    stack -= amount;
    return amount;
}

int player::bet() {
    double bet = 3 * 3;
    stack -= bet;
    return bet;
}