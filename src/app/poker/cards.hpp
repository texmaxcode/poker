#ifndef MUSCLE_COMPUTING_CARDS_H
#define MUSCLE_COMPUTING_CARDS_H

#include <vector>
#include <stack>
#include <iostream>
#include <string>

#include "utils.hpp"

enum class Suite
{
    CLUBS = 1,
    SPADES,
    HEARTS,
    DIAMONDS
};

enum class Rank
{
    TWO = 2,
    THREE,
    FOUR,
    FIVE,
    SIX,
    SEVEN,
    EIGHT,
    NINE,
    TEN,
    JACK,
    QUIN,
    KING,
    ACE
};


class card
{
public:
    Rank rank;
    Suite suite;
    card(Rank rank, Suite suite) : rank(rank), suite(suite) {};
    bool operator<(const card &) const;
    bool operator>(const card &) const;
    bool operator==(const card &) const;
    bool operator!=(const card &) const;
    friend std::ostream& operator<<(std::ostream &out, const card& card);
};

class card_deck
{
    std::stack<card> cards;
    std::vector<Rank> ranks{Rank::TWO, Rank::THREE, Rank::FOUR, Rank::FIVE, Rank::SIX, Rank::SEVEN, Rank::EIGHT, Rank::NINE, Rank::TEN, Rank::JACK, Rank::QUIN, Rank::KING, Rank::ACE};
    std::vector<Suite> suites{Suite::CLUBS, Suite::DIAMONDS, Suite::HEARTS, Suite::SPADES};

public:
    card_deck();
    card get_card();
};

#endif // MUSCLE_COMPUTING_CARDS_H
