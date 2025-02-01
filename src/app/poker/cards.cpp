#include "cards.hpp"

bool card::operator<(const card &another) const
{
    return rank < another.rank;
}

bool card::operator>(const card &another) const
{
    return rank > another.rank;
}

bool card::operator==(const card &another) const
{
    return rank == another.rank;
}

bool card::operator!=(const card &another) const
{
    return rank != another.rank;
}

card_deck::card_deck()
{
    for (const auto &suite : suites)
    {
        for (const auto &rank : ranks)
        {
            cards.push({rank, suite});
        }
    }
}

card card_deck::get_card()
{
    auto a_card = cards.top();
    cards.pop();
    return a_card;
}

std::string rank_to_string(Rank rank)
{
    switch (as_integer(rank))
    {
    case 2:
        return "2";
    case 3:
        return "3";
    case 4:
        return "4";
    case 5:
        return "5";
    case 6:
        return "6";
    case 7:
        return "7";
    case 8:
        return "8";
    case 9:
        return "9";
    case 10:
        return "T";
    case 11:
        return "J";
    case 12:
        return "Q";
    case 13:
        return "K";
    case 14:
        return "A";
    }
}

std::string suite_to_string(Suite suite)
{
    switch (as_integer(suite))
    {
    case 1:
        return "c";
    case 2:
        return "s";
    case 3:
        return "h";
    case 4:
        return "d";
    }
}

std::string stringify(Rank rank, Suite suite)
{
    return rank_to_string(rank) + suite_to_string(suite);
}

std::ostream &operator<<(std::ostream &out, const card &card)
{
    return out << "Card(" << stringify(card.rank, card.suite) << ")";
}
