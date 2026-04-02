#include "cards.hpp"

#include <array>

namespace {

QString rank_to_qml_asset_token(Rank r)
{
    switch (r)
    {
    case Rank::TWO:
        return QStringLiteral("2");
    case Rank::THREE:
        return QStringLiteral("3");
    case Rank::FOUR:
        return QStringLiteral("4");
    case Rank::FIVE:
        return QStringLiteral("5");
    case Rank::SIX:
        return QStringLiteral("6");
    case Rank::SEVEN:
        return QStringLiteral("7");
    case Rank::EIGHT:
        return QStringLiteral("8");
    case Rank::NINE:
        return QStringLiteral("9");
    case Rank::TEN:
        return QStringLiteral("10");
    case Rank::JACK:
        return QStringLiteral("jack");
    case Rank::QUEEN:
        return QStringLiteral("queen");
    case Rank::KING:
        return QStringLiteral("king");
    case Rank::ACE:
        return QStringLiteral("ace");
    }
    return QStringLiteral("2");
}

QString suite_to_qml_asset_token(Suite s)
{
    switch (as_integer(s))
    {
    case 1:
        return QStringLiteral("clubs");
    case 2:
        return QStringLiteral("spades");
    case 3:
        return QStringLiteral("hearts");
    case 4:
        return QStringLiteral("diamonds");
    default:
        return QStringLiteral("clubs");
    }
}

} // namespace

QString card_to_display_string(const card &c)
{
    QString r;
    switch (c.rank)
    {
    case Rank::TWO:
        r = QStringLiteral("2");
        break;
    case Rank::THREE:
        r = QStringLiteral("3");
        break;
    case Rank::FOUR:
        r = QStringLiteral("4");
        break;
    case Rank::FIVE:
        r = QStringLiteral("5");
        break;
    case Rank::SIX:
        r = QStringLiteral("6");
        break;
    case Rank::SEVEN:
        r = QStringLiteral("7");
        break;
    case Rank::EIGHT:
        r = QStringLiteral("8");
        break;
    case Rank::NINE:
        r = QStringLiteral("9");
        break;
    case Rank::TEN:
        r = QStringLiteral("T");
        break;
    case Rank::JACK:
        r = QStringLiteral("J");
        break;
    case Rank::QUEEN:
        r = QStringLiteral("Q");
        break;
    case Rank::KING:
        r = QStringLiteral("K");
        break;
    case Rank::ACE:
        r = QStringLiteral("A");
        break;
    default:
        r = QStringLiteral("?");
        break;
    }
    QString s;
    switch (c.suite)
    {
    case Suite::CLUBS:
        s = QStringLiteral("c");
        break;
    case Suite::SPADES:
        s = QStringLiteral("s");
        break;
    case Suite::HEARTS:
        s = QStringLiteral("h");
        break;
    case Suite::DIAMONDS:
        s = QStringLiteral("d");
        break;
    default:
        s = QStringLiteral("?");
        break;
    }
    return r + s;
}

QString card_to_qml_asset_path(const card &c)
{
    static const std::array<QString, 52> k_path_table = [] {
        std::array<QString, 52> a{};
        size_t idx = 0;
        for (int ri = 0; ri < 13; ++ri)
        {
            const Rank r = static_cast<Rank>(ri + static_cast<int>(Rank::TWO));
            for (int si = 0; si < 4; ++si)
            {
                const Suite s = static_cast<Suite>(si + static_cast<int>(Suite::CLUBS));
                a[idx++] = suite_to_qml_asset_token(s) + QLatin1Char('_') + rank_to_qml_asset_token(r)
                    + QStringLiteral(".svg");
            }
        }
        return a;
    }();
    const int ri = static_cast<int>(c.rank) - static_cast<int>(Rank::TWO);
    const int si = static_cast<int>(c.suite) - static_cast<int>(Suite::CLUBS);
    if (ri >= 0 && ri < 13 && si >= 0 && si < 4)
        return k_path_table[static_cast<size_t>(ri * 4 + si)];
    return suite_to_qml_asset_token(c.suite) + QLatin1Char('_') + rank_to_qml_asset_token(c.rank) + QStringLiteral(".svg");
}

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
    return rank == another.rank && suite == another.suite;
}

bool card::operator!=(const card &another) const
{
    return !(*this == another);
}

card_deck::card_deck()
{
    for (const auto &suite : suites)
    {
        for (const auto &rank : ranks)
        {
            cards.push_back({rank, suite});
        }
    }
    shuffle();
}

void card_deck::shuffle()
{
    // Might be good for testing.
    // auto random_engine = std::default_random_engine{};
    std::random_device rd;
    std::mt19937 generator(rd());
    std::shuffle(cards.begin(), cards.end(), generator);
}

card card_deck::get_card()
{
    auto a_card = cards.back();
    cards.pop_back();
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
    return UNKNOWN;
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
    return UNKNOWN;
}

std::string stringify(Rank rank, Suite suite)
{
    return rank_to_string(rank) + suite_to_string(suite);
}

std::ostream &operator<<(std::ostream &out, const card &card)
{
    return out << stringify(card.rank, card.suite);
}
