#include "equity_engine.hpp"

#include "hand_eval.hpp"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <sstream>

namespace {

std::vector<card> make_full_deck()
{
    std::vector<card> d;
    d.reserve(52);
    for (int s = 1; s <= 4; ++s)
    {
        for (int r = 2; r <= 14; ++r)
            d.push_back(card(static_cast<Rank>(r), static_cast<Suite>(s)));
    }
    return d;
}

std::vector<card> available_cards(const std::vector<card> &dead)
{
    auto d = make_full_deck();
    d.erase(std::remove_if(d.begin(), d.end(), [&](const card &c) {
                 for (const auto &x : dead)
                 {
                     if (x == c)
                         return true;
                 }
                 return false;
             }),
             d.end());
    return d;
}

Rank rank_from_char(char ch)
{
    switch (std::toupper(static_cast<unsigned char>(ch)))
    {
    case 'A':
        return Rank::ACE;
    case 'K':
        return Rank::KING;
    case 'Q':
        return Rank::QUEEN;
    case 'J':
        return Rank::JACK;
    case 'T':
        return Rank::TEN;
    case '9':
        return Rank::NINE;
    case '8':
        return Rank::EIGHT;
    case '7':
        return Rank::SEVEN;
    case '6':
        return Rank::SIX;
    case '5':
        return Rank::FIVE;
    case '4':
        return Rank::FOUR;
    case '3':
        return Rank::THREE;
    case '2':
        return Rank::TWO;
    default:
        return Rank::TWO;
    }
}

Suite suite_from_char(char ch)
{
    switch (std::tolower(static_cast<unsigned char>(ch)))
    {
    case 'c':
        return Suite::CLUBS;
    case 's':
        return Suite::SPADES;
    case 'h':
        return Suite::HEARTS;
    case 'd':
        return Suite::DIAMONDS;
    default:
        return Suite::CLUBS;
    }
}

bool rank_char_valid(char ch)
{
    switch (std::toupper(static_cast<unsigned char>(ch)))
    {
    case 'A':
    case 'K':
    case 'Q':
    case 'J':
    case 'T':
    case '9':
    case '8':
    case '7':
    case '6':
    case '5':
    case '4':
    case '3':
    case '2':
        return true;
    default:
        return false;
    }
}

bool suite_char_valid(char ch)
{
    switch (std::tolower(static_cast<unsigned char>(ch)))
    {
    case 'c':
    case 's':
    case 'h':
    case 'd':
        return true;
    default:
        return false;
    }
}

std::vector<card> complete_board_random(std::vector<card> board, const std::vector<card> &dead_in,
                                         std::mt19937 &rng)
{
    std::vector<card> dead = dead_in;
    while (board.size() < 5)
    {
        auto avail = available_cards(dead);
        if (avail.empty())
            break;
        std::uniform_int_distribution<size_t> dist(0, avail.size() - 1);
        const card pick = avail[dist(rng)];
        board.push_back(pick);
        dead.push_back(pick);
    }
    while (board.size() > 5)
        board.pop_back();
    return board;
}

double showdown_equity_pick(const std::vector<card> &hero7, const std::vector<card> &villain7)
{
    const int cmp = compare_holdem_hands(hero7, villain7);
    if (cmp > 0)
        return 1.0;
    if (cmp < 0)
        return 0.0;
    return 0.5;
}

} // namespace

bool parse_card_string(const std::string &tok_in, card &out)
{
    std::string s = tok_in;
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.front())))
        s.erase(s.begin());
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back())))
        s.pop_back();
    if (s.size() >= 3 && s[0] == '1' && s[1] == '0')
    {
        if (!suite_char_valid(s[2]))
            return false;
        out.rank = Rank::TEN;
        out.suite = suite_from_char(s[2]);
        return true;
    }
    if (s.size() < 2)
        return false;
    if (!rank_char_valid(s[0]) || !suite_char_valid(s[1]))
        return false;
    out.rank = rank_from_char(s[0]);
    out.suite = suite_from_char(s[1]);
    return true;
}

bool parse_board_string(const std::string &line, std::vector<card> &out, std::string &err)
{
    out.clear();
    std::stringstream ss(line);
    std::string tok;
    while (ss >> tok)
    {
        if (tok.empty())
            continue;
        card c;
        if (!parse_card_string(tok, c))
        {
            err = "Bad card token: " + tok;
            return false;
        }
        for (const auto &e : out)
        {
            if (e == c)
            {
                err = "Duplicate card in board";
                return false;
            }
        }
        out.push_back(c);
    }
    if (out.size() > 5)
    {
        err = "Board has more than 5 cards";
        return false;
    }
    return true;
}

static bool sample_villain_hole(const RangeMatrix &rm, std::vector<card> dead, card &a, card &b,
                                std::mt19937 &rng)
{
    std::uniform_real_distribution<double> U(0.0, 1.0);
    for (int attempt = 0; attempt < 500; ++attempt)
    {
        auto avail = available_cards(dead);
        if (avail.size() < 2)
            return false;
        std::shuffle(avail.begin(), avail.end(), rng);
        a = avail[0];
        b = avail[1];
        const double w = rm.weight(a, b);
        if (w <= 0.0)
            continue;
        if (U(rng) < w)
            return true;
    }
    for (int attempt = 0; attempt < 2000; ++attempt)
    {
        auto avail = available_cards(dead);
        if (avail.size() < 2)
            return false;
        std::shuffle(avail.begin(), avail.end(), rng);
        a = avail[0];
        b = avail[1];
        if (rm.weight(a, b) > 1e-9)
            return true;
    }
    return false;
}

EquityResult monte_carlo_equity_vs_range(const card &hero1, const card &hero2,
                                         const std::vector<card> &board_in, const RangeMatrix &villain_range,
                                         int iterations, std::mt19937 &rng)
{
    EquityResult r;
    if (iterations < 1)
    {
        r.error = "iterations must be >= 1";
        return r;
    }

    std::vector<card> dead = {hero1, hero2};
    for (const auto &c : board_in)
        dead.push_back(c);

    double sum = 0;
    int n = 0;
    for (int i = 0; i < iterations; ++i)
    {
        card v1, v2;
        if (!sample_villain_hole(villain_range, dead, v1, v2, rng))
        {
            r.error = "Could not sample villain hole from range (too tight vs dead cards?)";
            return r;
        }
        std::vector<card> dead2 = dead;
        dead2.push_back(v1);
        dead2.push_back(v2);
        std::vector<card> board = board_in;
        board = complete_board_random(board, dead2, rng);
        if (board.size() < 5)
        {
            r.error = "Could not complete board";
            return r;
        }

        std::vector<card> h7 = {hero1, hero2};
        h7.insert(h7.end(), board.begin(), board.end());
        std::vector<card> y7 = {v1, v2};
        y7.insert(y7.end(), board.begin(), board.end());
        std::sort(h7.begin(), h7.end());
        std::sort(y7.begin(), y7.end());

        sum += showdown_equity_pick(h7, y7);
        ++n;
    }

    r.equity_hero = sum / static_cast<double>(n);
    r.iterations_used = n;
    const double p = r.equity_hero;
    r.std_err = std::sqrt(std::max(0.0, p * (1.0 - p) / static_cast<double>(n)));
    return r;
}

EquityResult monte_carlo_equity_vs_hand(const card &hero1, const card &hero2,
                                        const std::vector<card> &board_in, const card &villain1,
                                        const card &villain2, int iterations, std::mt19937 &rng)
{
    EquityResult r;
    if (iterations < 1)
    {
        r.error = "iterations must be >= 1";
        return r;
    }

    std::vector<card> dead = {hero1, hero2, villain1, villain2};
    for (const auto &c : board_in)
        dead.push_back(c);

    double sum = 0;
    int n = 0;
    for (int i = 0; i < iterations; ++i)
    {
        std::vector<card> board = board_in;
        board = complete_board_random(board, dead, rng);
        if (board.size() < 5)
        {
            r.error = "Could not complete board";
            return r;
        }

        std::vector<card> h7 = {hero1, hero2};
        h7.insert(h7.end(), board.begin(), board.end());
        std::vector<card> y7 = {villain1, villain2};
        y7.insert(y7.end(), board.begin(), board.end());
        std::sort(h7.begin(), h7.end());
        std::sort(y7.begin(), y7.end());

        sum += showdown_equity_pick(h7, y7);
        ++n;
    }

    r.equity_hero = sum / static_cast<double>(n);
    r.iterations_used = n;
    const double p = r.equity_hero;
    r.std_err = std::sqrt(std::max(0.0, p * (1.0 - p) / static_cast<double>(n)));
    return r;
}
