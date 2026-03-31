#include "game.hpp"

#include <array>
#include <iostream>

bool game::is_game_in_progress() const
{
    return in_progress;
}

void game::join_table(player player)
{
    bool more_than_ten_blinds = (player.stack >= 10 * big_blind);
    bool less_than_hundred_blinds = (player.stack <= 100 * big_blind);
    bool has_enough_money = more_than_ten_blinds && less_than_hundred_blinds;
    if (has_enough_money)
        table.push_back(player);
}

int game::players_count() const
{
    return table.size();
}

static int next_player_idx(int button, int offset, int player_count)
{
    if (player_count <= 0)
        return 0;
    return (button + offset) % player_count;
}

void game::collect_blinds()
{
    if (players_count() == 2)
    {
        pot += table[next_player_idx(button, 0, players_count())].pay(big_blind);
        pot += table[next_player_idx(button, 1, players_count())].pay(small_blind);
    }
    emit pot_changed();
}

void game::take_bets()
{
    if (players_count() == 2)
    {
        pot += table[next_player_idx(button, 0, players_count())].bet();
        pot += table[next_player_idx(button, 1, players_count())].bet();
    }
    emit pot_changed();
}

void game::deal_hold_cards()
{
    if (players_count() == 2)
    {
        const auto first = next_player_idx(button, 0, players_count());
        const auto second = next_player_idx(button, 1, players_count());

        table[first].first_card = deck.get_card();
        table[second].first_card = deck.get_card();

        table[first].second_card = deck.get_card();
        table[second].second_card = deck.get_card();
    }
}

void game::deal_flop()
{
    (void)deck.get_card(); // burn
    for (auto i = 0; i < 3; ++i)
    {
        flop.push_back(deck.get_card());
    }
}

void game::deal_turn()
{
    (void)deck.get_card(); // burn
    turn = deck.get_card();
}

void game::deal_river()
{
    (void)deck.get_card(); // burn
    river = deck.get_card();
}

std::string stringify(std::vector<card> card_vector)
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

std::string game::evaluator(const std::vector<card> &hand)
{
    // Minimal evaluator: enough to be useful in logs and avoid unused vars.
    // Expects a 7-card hand vector.
    std::array<int, 15> rank_counts{};
    std::array<int, 5> suite_counts{};

    for (const auto &c : hand)
    {
        const auto r = as_integer(c.rank);
        const auto s = as_integer(c.suite);
        if (r >= 2 && r <= 14)
            rank_counts[static_cast<size_t>(r)]++;
        if (s >= 1 && s <= 4)
            suite_counts[static_cast<size_t>(s)]++;
    }

    bool has_flush = false;
    for (int s = 1; s <= 4; ++s)
    {
        if (suite_counts[static_cast<size_t>(s)] >= 5)
        {
            has_flush = true;
            break;
        }
    }

    int pairs = 0;
    bool trips = false;
    bool quads = false;
    for (int r = 2; r <= 14; ++r)
    {
        const auto cnt = rank_counts[static_cast<size_t>(r)];
        if (cnt == 2)
            pairs++;
        else if (cnt == 3)
            trips = true;
        else if (cnt == 4)
            quads = true;
    }

    if (quads)
        return "Four of a kind";
    if (trips && pairs > 0)
        return "Full house";
    if (has_flush)
        return "Flush";
    if (trips)
        return "Three of a kind";
    if (pairs >= 2)
        return "Two pair";
    if (pairs == 1)
        return "Pair";
    return "High card";
}

void game::decide_the_payout()
{
    auto hand_one = get_hand_vector(next_player_idx(button, 0, players_count()));
    auto hand_two = get_hand_vector(next_player_idx(button, 1, players_count()));
    std::cout << stringify(hand_one) << " " << evaluator(hand_one) << std::endl;
    std::cout << stringify(hand_two) << " " << evaluator(hand_two) << std::endl;
}

void game::start()
{
    clearAll();
    std::cout << "Starting a game." << std::endl;
    in_progress = true;
    street = Street::PRE_FLOP;
    std::cout << "Preflop pot: " << pot << std::endl;
    collect_blinds();
    deal_hold_cards();
    take_bets();
    street = Street::FLOP;
    std::cout << "Flop pot: " << pot << std::endl;
    deal_flop();
    take_bets();
    street = Street::TURN;
    std::cout << "Turn pot: " << pot << std::endl;
    deal_turn();
    take_bets();
    street = Street::RIVER;
    deal_river();
    take_bets();
    std::cout << "River pot: " << pot << std::endl;
    /*
    decide_the_payout();
    do_payouts();
    switch_button();
    */
}

void game::setRootObject(QObject *root)
{
    // disconnect from previous root
    if (m_root != nullptr)
        m_root->disconnect(this);

    m_root = root;

    if (m_root)
    {
        connect(m_root, SIGNAL(buttonClicked(QString)), this, SLOT(buttonClicked(QString)));
        // set initial state
        clearAll();
    }
}

void game::clearAll()
{
    pot = 0;
    flop.clear();
    deck = card_deck{};

    if (m_root)
        emit pot_changed();
}

game::game(QObject *parent) : QObject(parent), m_root(nullptr)
{
    player player_one;
    player_one.stack = 100;
    player player_two;
    player_two.stack = 100;
    join_table(player_one);
    join_table(player_two);

    QObject::connect(this, &game::pot_changed, this, &game::on_pot_changed);
}

void game::on_pot_changed()
{
    if (m_root)
    {
        m_root->setProperty("pot", pot);
    }
}

void game::buttonClicked(QString button)
{
    if (!m_root)
        return;
    start();
}
