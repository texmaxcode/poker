#ifndef MUSCLE_COMPUTING_CARDS_H
#define MUSCLE_COMPUTING_CARDS_H

#include <vector>
#include <iostream>
#include <string>

#include "utils.hpp"
#include <algorithm>
#include <random>

#define UNKNOWN "Unknown"

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

enum class HandRank
{
    HIGH_CARD = 1,
    PAIR,
    TWO_PAIR,
    THREE_OF_A_KIND,
    STRAIGHT,
    FLUSH,
    FULL_HOUSE,
    FOUR_OF_A_KIND,
    STRAIGHT_FLUSH,
    ROYAL_FLUSH
};

class card
{
public:
    Rank rank;
    Suite suite;
    card() {};
    card(Rank rank, Suite suite) : rank(rank), suite(suite) {};
    bool operator<(const card &) const;
    bool operator>(const card &) const;
    bool operator==(const card &) const;
    bool operator!=(const card &) const;
    friend std::ostream &operator<<(std::ostream &out, const card &card);
};

class card_deck
{
    std::vector<card> cards;
    std::vector<Rank> ranks{Rank::TWO, Rank::THREE, Rank::FOUR, Rank::FIVE, Rank::SIX, Rank::SEVEN, Rank::EIGHT, Rank::NINE, Rank::TEN, Rank::JACK, Rank::QUIN, Rank::KING, Rank::ACE};
    std::vector<Suite> suites{Suite::CLUBS, Suite::DIAMONDS, Suite::HEARTS, Suite::SPADES};
    void shuffle();

public:
    card_deck();
    card get_card();
};

#endif // MUSCLE_COMPUTING_CARDS_H
