#include "game.hpp"

bool game::is_game_in_progress()
{
    return in_progress;
}

void game::join_table(player &player)
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

void game::start()
{
    in_progress = true;
    collect_blinds();
    deal_hold_cards();
    take_bets();
    /*
    deal_flop();
    take_bets();
    deal_turn();
    take_bets();
    deal_river();
    take_bets();
    decide_the_payout();
    do_payouts();
    switch_button();
    */
}