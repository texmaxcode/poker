#include "game.hpp"

bool game::is_game_in_progress()
{
    return in_progress;
}

void game::join_table(player player)
{
    bool more_than_ten_blinds = (player.stack >= 10 * big_blind);
    bool less_than_hundrad_blinds = (player.stack <= 100 * big_blind);
    bool has_enough_money = more_than_ten_blinds && less_than_hundrad_blinds;
    if (has_enough_money)
        table.push_back(player);
}

int game::players_count()
{
    return table.size();
}

void game::collect_blinds()
{
    if (players_count() == 2)
    {
        pot += table[button].pay(big_blind);
        pot += table[button + 1].pay(small_blind);
    }
}

void game::take_bets()
{
    if (players_count() == 2)
    {
        pot += table[button].bet();
        pot += table[button + 1].bet();
    }
}

void game::deal_hold_cards()
{
    if (players_count() == 2)
    {
        for (auto i = 0; i < 2; ++i)
        {
            for (auto &player : table)
            {
                if (i == 0)
                {
                    table[button].first_card = deck.get_card();
                    table[button + 1].first_card = deck.get_card();
                }
                else
                {
                    table[button].second_card = deck.get_card();
                    table[button + 1].second_card = deck.get_card();
                }
            }
        }
    }
}

void game::deal_flop()
{
    card burn_card = deck.get_card();
    for (auto i = 0; i < 3; ++i)
    {
        flop.push_back(deck.get_card());
    }
}

void game::deal_turn() {
    card burn_card = deck.get_card();
    turn = deck.get_card();
}

void game::deal_river() {
    card burn_card = deck.get_card();
    river = deck.get_card();
}

std::string get_hand_for_player(player player, std::vector<card> flop, card turn, card river) {
    std::string hand = "";
    hand += to_string(player.first_card);
    hand += to_string(player.second_card);
    hand += to_string(flop[0]);
    hand += to_string(flop[1]);
    hand += to_string(flop[2]);
    hand += to_string(turn);
    hand += to_string(river);
    return hand;
}

void game::decide_the_payout() {
    std::string hand_one = get_hand_for_player(table[button], flop, turn, river);
    std::string hand_two = get_hand_for_player(table[button + 1], flop, turn, river);
    std::cout << hand_one << std::endl;
    std::cout << hand_two << std::endl;
}

void game::start()
{
    in_progress = true;
    street == Street::PRE_FLOP;
    collect_blinds();
    deal_hold_cards();
    take_bets();
    street == Street::FLOP;
    deal_flop();
    take_bets();
    street == Street::TURN;
    deal_turn();
    take_bets();
    street == Street::RIVER;
    deal_river();
    take_bets();
    decide_the_payout();
    /*
    do_payouts();
    switch_button();
    */
}