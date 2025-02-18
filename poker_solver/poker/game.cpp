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

    std::cout << players_count() << std::endl;
    if (players_count() == 2)
    {
        pot += table[button].pay(big_blind);
        pot += table[button + 1].pay(small_blind);
        std::cout << pot << std::endl;
        emit pot_changed();
    }
}

void game::take_bets()
{
    std::cout << players_count() << std::endl;
    if (players_count() == 2)
    if (players_count() == 2)
    {
        pot += table[button].bet();
        pot += table[button + 1].bet();
        std::cout << pot << std::endl;
        emit pot_changed();
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

std::string game::evaluator(std::vector<card> hand)
{
    int clubs{0};
    int dimonds{0};
    int spades{0};
    int hearts{0};
    int two{0};
    int three{0};
    int four{0};
    int five{0};
    int six{0};
    int seven{0};
    int eight{0};
    int nine{0};
    int ten{0};
    int jack{0};
    int qeen{0};
    int king{0};
    int ace{0};

    for (auto card : hand)
    {
        switch (as_integer(card.suite))
        {
        case 1:
            clubs++;
            break;
        case 2:
            spades++;
            break;
        case 3:
            hearts++;
            break;
        case 4:
            dimonds++;
            break;
        }
    }

    for (auto card : hand)
    {
        switch (as_integer(card.rank))
        {
        case 2:
            two++;
            break;
        case 3:
            three++;
            break;
        case 4:
            four++;
            break;
        case 5:
            five++;
            break;
        case 6:
            six++;
            break;
        case 7:
            seven++;
            break;
        case 8:
            eight++;
            break;
        case 9:
            nine++;
            break;
        case 10:
            ten++;
            break;
        case 11:
            jack++;
            break;
        case 12:
            qeen++;
            break;
        case 13:
            king++;
            break;
        case 14:
            ace++;
            break;
        }
    }
    return "Some lucky type";
}

void game::decide_the_payout()
{
    auto hand_one = get_hand_vector(button);
    auto hand_two = get_hand_vector(button + 1);
    std::cout << stringify(hand_one) << " " << evaluator(hand_one) << std::endl;
    std::cout << stringify(hand_two) << " " << evaluator(hand_two) << std::endl;
}

void game::start()
{
    clearAll();
    std::cout << "Starting a game." << std::endl;
    in_progress = true;
    street == Street::PRE_FLOP;
    std::cout << "Preflop" << std::endl;
    collect_blinds();
    emit pot_changed();
    deal_hold_cards();
    take_bets();
    emit pot_changed();
    street == Street::FLOP;
    std::cout << "Flop" << std::endl;
    deal_flop();
    take_bets();
    emit pot_changed();
    street == Street::TURN;
    deal_turn();
    take_bets();
    emit pot_changed();
    street == Street::RIVER;
    deal_river();
    take_bets();
    /*
    decide_the_payout();
    do_payouts();
    switch_button();
    */
}

void game::setRootObject(QQuickItem *root)
{
    // disconnect from previous root
    if (m_root != nullptr)
        m_root->disconnect(this);

    m_root = root;

    if (m_root)
    {
        // set initial state
        clearAll();
    }
}

void game::clearAll()
{
    if (m_root)
    {
        pot = 0;
        emit pot_changed();
    }
}

game::game(QObject *parent) : QObject(parent), m_root(nullptr)
{
    player player_one;
    player_one.stack = 100;
    player player_two;
    player_two.stack = 100;

    join_table(player_one);
    join_table(player_two);

    QObject::connect(this, &game::pot_changed, this, &game::onPotChanged);
}

game::~game() {}

void game::onPotChanged()
{
    if (m_root)
        m_root->setProperty("pot", QVariant(pot));
}