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

void game::deal_turn()
{
    card burn_card = deck.get_card();
    turn = deck.get_card();
}

void game::deal_river()
{
    card burn_card = deck.get_card();
    river = deck.get_card();
}

std::string string_representation(std::vector<card> card_vector)
{
    std::string hand = "";
    hand += to_string(card_vector[0]);
    hand += to_string(card_vector[1]);
    hand += to_string(card_vector[2]);
    hand += to_string(card_vector[3]);
    hand += to_string(card_vector[4]);
    hand += to_string(card_vector[5]);
    hand += to_string(card_vector[6]);
    return hand;
}

std::vector<card> game::get_hand_vector(int idx)
{
    std::vector<card> return_vector;

    return_vector.push_back(table[idx].first_card);
    return_vector.push_back(table[idx].second_card);
    return_vector.push_back(flop[0]);
    return_vector.push_back(flop[1]);
    return_vector.push_back(flop[2]);
    return_vector.push_back(turn);
    return_vector.push_back(river);
    std::sort(return_vector.begin(), return_vector.end());

    return return_vector;
}

void game::decide_the_payout()
{
    std::cout << string_representation(get_hand_vector(button)) << std::endl;
    std::cout << string_representation(get_hand_vector(button + 1)) << std::endl;
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