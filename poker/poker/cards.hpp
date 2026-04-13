#ifndef TEXAS_HOLDEM_GYM_CARDS_H
#define TEXAS_HOLDEM_GYM_CARDS_H

#include <iosfwd>
#include <string>
#include <type_traits>
#include <vector>

#include <QString>

#define UNKNOWN "Unknown"

template <typename Enumeration>
auto as_integer(Enumeration const value) -> typename std::underlying_type<Enumeration>::type
{
  return static_cast<typename std::underlying_type<Enumeration>::type>(value);
}

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
    QUEEN,
    KING,
    ACE
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

inline bool same_rank(const card &a, const card &b)
{
    return a.rank == b.rank;
}

class card_deck
{
    std::vector<card> cards;
    std::vector<Rank> ranks{Rank::TWO, Rank::THREE, Rank::FOUR, Rank::FIVE, Rank::SIX, Rank::SEVEN, Rank::EIGHT, Rank::NINE, Rank::TEN, Rank::JACK, Rank::QUEEN, Rank::KING, Rank::ACE};
    std::vector<Suite> suites{Suite::CLUBS, Suite::DIAMONDS, Suite::HEARTS, Suite::SPADES};
    void shuffle();

public:
    card_deck();
    card get_card();
};

/// Resource name for QML SVG assets: `"<suite>_<rank>.svg"` (e.g. `clubs_ace.svg`).
QString card_to_qml_asset_path(const card &c);

/// Short notation for UI text, e.g. `"Ah"`, `"Td"` (rank + suit letter).
QString card_to_display_string(const card &c);

#endif // TEXAS_HOLDEM_GYM_CARDS_H
