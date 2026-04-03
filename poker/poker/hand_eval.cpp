#include "hand_eval.hpp"

#include <algorithm>
#include <array>
#include <cassert>
#include <cmath>
#include <vector>

namespace detail {

int rank_value(Rank r)
{
    return static_cast<int>(r);
}

bool is_flush_5(const std::array<card, 5> &h)
{
    const auto s = h[0].suite;
    for (int i = 1; i < 5; ++i)
    {
        if (h[i].suite != s)
            return false;
    }
    return true;
}

/// Returns {is_straight, high_card} — wheel uses high 5 (ace low).
std::pair<bool, int> straight_high(const std::array<int, 5> &ranks_asc)
{
    std::array<int, 5> r = ranks_asc;
    std::sort(r.begin(), r.end());
    if (r[0] == 2 && r[1] == 3 && r[2] == 4 && r[3] == 5 && r[4] == 14)
        return {true, 5};
    bool ok = true;
    for (int i = 0; i < 4; ++i)
    {
        if (r[i + 1] - r[i] != 1)
        {
            ok = false;
            break;
        }
    }
    if (ok)
        return {true, r[4]};
    return {false, 0};
}

std::array<int, 8> evaluate_5(const std::array<card, 5> &h)
{
    std::array<int, 8> out{};
    std::array<int, 5> rv{};
    for (int i = 0; i < 5; ++i)
        rv[i] = rank_value(h[i].rank);
    std::sort(rv.begin(), rv.end());

    std::array<int, 15> cnt{};
    for (int v : rv)
        cnt[static_cast<size_t>(v)]++;

    const bool flush = is_flush_5(h);
    const auto st = straight_high(rv);
    const bool straight = st.first;

    if (flush && straight)
    {
        out[0] = 8;
        out[1] = st.second;
        return out;
    }

    int quad_rank = 0;
    int trip_rank = 0;
    int pair1 = 0;
    int pair2 = 0;
    for (int r = 14; r >= 2; --r)
    {
        const int c = cnt[static_cast<size_t>(r)];
        if (c == 4)
            quad_rank = r;
        else if (c == 3)
            trip_rank = r;
        else if (c == 2)
        {
            if (pair1 == 0)
                pair1 = r;
            else
                pair2 = r;
        }
    }

    if (quad_rank > 0)
    {
        out[0] = 7;
        out[1] = quad_rank;
        for (int r = 14; r >= 2; --r)
        {
            if (cnt[static_cast<size_t>(r)] == 1)
            {
                out[2] = r;
                break;
            }
        }
        return out;
    }

    if (trip_rank > 0 && pair1 > 0 && pair1 != trip_rank)
    {
        out[0] = 6;
        out[1] = trip_rank;
        out[2] = pair1;
        return out;
    }

    if (flush)
    {
        out[0] = 5;
        std::array<int, 5> desc = rv;
        std::sort(desc.begin(), desc.end(), std::greater<int>());
        for (int i = 0; i < 5; ++i)
            out[1 + i] = desc[i];
        return out;
    }

    if (straight)
    {
        out[0] = 4;
        out[1] = st.second;
        return out;
    }

    if (trip_rank > 0)
    {
        out[0] = 3;
        out[1] = trip_rank;
        int k = 2;
        for (int r = 14; r >= 2 && k < 4; --r)
        {
            if (cnt[static_cast<size_t>(r)] == 1)
            {
                out[k++] = r;
            }
        }
        return out;
    }

    if (pair1 > 0 && pair2 > 0)
    {
        const int hi = std::max(pair1, pair2);
        const int lo = std::min(pair1, pair2);
        out[0] = 2;
        out[1] = hi;
        out[2] = lo;
        for (int r = 14; r >= 2; --r)
        {
            if (cnt[static_cast<size_t>(r)] == 1)
            {
                out[3] = r;
                break;
            }
        }
        return out;
    }

    if (pair1 > 0)
    {
        out[0] = 1;
        out[1] = pair1;
        int k = 2;
        for (int r = 14; r >= 2 && k < 5; --r)
        {
            if (cnt[static_cast<size_t>(r)] == 1)
                out[k++] = r;
        }
        return out;
    }

    out[0] = 0;
    std::array<int, 5> desc = rv;
    std::sort(desc.begin(), desc.end(), std::greater<int>());
    for (int i = 0; i < 5; ++i)
        out[1 + i] = desc[i];
    return out;
}

static bool mask_5_of_7(int mask)
{
    int bits = 0;
    for (int m = mask; m != 0; m >>= 1)
        bits += (m & 1);
    return bits == 5;
}

std::array<int, 8> best_of_seven(const std::vector<card> &seven_cards)
{
    assert(seven_cards.size() == 7);
    /// Permutation-invariant: same seven cards in any order must yield the same best hand.
    std::vector<card> cards = seven_cards;
    std::sort(cards.begin(), cards.end(), [](const card &a, const card &b) { return a < b; });

    std::array<int, 8> best{};
    bool have = false;
    for (int mask = 0; mask < 128; ++mask)
    {
        if (!mask_5_of_7(mask))
            continue;
        std::array<card, 5> five{};
        int p = 0;
        for (int i = 0; i < 7; ++i)
        {
            if (mask & (1 << i))
                five[p++] = cards[static_cast<size_t>(i)];
        }
        const auto sc = evaluate_5(five);
        if (!have || std::lexicographical_compare(best.begin(), best.end(), sc.begin(), sc.end()))
        {
            best = sc;
            have = true;
        }
    }
    assert(have);
    return best;
}

static bool mask_k_of_n(int mask, int k, int n)
{
    int bits = 0;
    for (int i = 0; i < n; ++i)
    {
        if (mask & (1 << i))
            ++bits;
    }
    return bits == k;
}

std::array<int, 8> best_hand_score_variable(const std::vector<card> &cards)
{
    const size_t n = cards.size();
    assert(n >= 5 && n <= 7);
    if (n == 5)
    {
        std::array<card, 5> five{};
        for (size_t i = 0; i < 5; ++i)
            five[i] = cards[i];
        return evaluate_5(five);
    }
    if (n == 7)
        return best_of_seven(cards);

    std::array<int, 8> best{};
    const int limit = 1 << static_cast<int>(n);
    for (int mask = 0; mask < limit; ++mask)
    {
        if (!mask_k_of_n(mask, 5, static_cast<int>(n)))
            continue;
        std::array<card, 5> five{};
        int p = 0;
        for (int i = 0; i < static_cast<int>(n); ++i)
        {
            if (mask & (1 << i))
                five[p++] = cards[static_cast<size_t>(i)];
        }
        const auto sc = evaluate_5(five);
        if (std::lexicographical_compare(best.begin(), best.end(), sc.begin(), sc.end()))
            best = sc;
    }
    return best;
}

static bool card_display_order(const card &a, const card &b)
{
    if (a.rank != b.rank)
        return static_cast<int>(a.rank) > static_cast<int>(b.rank);
    return static_cast<int>(a.suite) > static_cast<int>(b.suite);
}

std::vector<card> best_five_cards_for_display_impl(const std::vector<card> &cards)
{
    const size_t n = cards.size();
    if (n == 0)
        return {};
    if (n < 5)
        return cards;

    std::array<int, 8> best{};
    std::array<card, 5> best_five{};
    bool have = false;
    const int limit = 1 << static_cast<int>(n);
    for (int mask = 0; mask < limit; ++mask)
    {
        if (!mask_k_of_n(mask, 5, static_cast<int>(n)))
            continue;
        std::array<card, 5> five{};
        int p = 0;
        for (int i = 0; i < static_cast<int>(n); ++i)
        {
            if (mask & (1 << i))
                five[p++] = cards[static_cast<size_t>(i)];
        }
        const auto sc = evaluate_5(five);
        if (!have || std::lexicographical_compare(best.begin(), best.end(), sc.begin(), sc.end()))
        {
            best = sc;
            best_five = five;
            have = true;
        }
    }
    if (!have)
        return {};
    std::vector<card> out(best_five.begin(), best_five.end());
    std::sort(out.begin(), out.end(), card_display_order);
    return out;
}

} // namespace detail

std::vector<card> best_five_cards_for_display(const std::vector<card> &cards)
{
    return detail::best_five_cards_for_display_impl(cards);
}

std::array<int, 8> best_hand_score(const std::vector<card> &seven_cards)
{
    return detail::best_of_seven(seven_cards);
}

int compare_holdem_hands(const std::vector<card> &seven_a, const std::vector<card> &seven_b)
{
    const auto a = best_hand_score(seven_a);
    const auto b = best_hand_score(seven_b);
    if (std::lexicographical_compare(a.begin(), a.end(), b.begin(), b.end()))
        return -1;
    if (std::lexicographical_compare(b.begin(), b.end(), a.begin(), a.end()))
        return 1;
    return 0;
}

static const char *rank_name(int r)
{
    switch (r)
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
        return "10";
    case 11:
        return "J";
    case 12:
        return "Q";
    case 13:
        return "K";
    case 14:
        return "A";
    default:
        return "?";
    }
}

std::string describe_holdem_hand(const std::vector<card> &cards)
{
    const size_t n = cards.size();
    if (n < 2)
        return {};
    if (n == 2)
    {
        const card &a = cards[0];
        const card &b = cards[1];
        if (a.rank == b.rank)
            return std::string("Pocket ") + rank_name(static_cast<int>(a.rank)) + "s";
        const int hi = std::max(static_cast<int>(a.rank), static_cast<int>(b.rank));
        const int lo = std::min(static_cast<int>(a.rank), static_cast<int>(b.rank));
        return std::string(rank_name(hi)) + " " + rank_name(lo);
    }
    if (n < 5)
        return {};
    return describe_hand_score(detail::best_hand_score_variable(cards));
}

std::string describe_hand_score(const std::array<int, 8> &s)
{
    const int cat = s[0];
    switch (cat)
    {
    case 8:
        if (s[1] == 14)
            return "Royal flush";
        return std::string("Straight flush, ") + rank_name(s[1]) + " high";
    case 7:
        return std::string("Four of a kind, ") + rank_name(s[1]) + "s";
    case 6:
        return std::string("Full house, ") + rank_name(s[1]) + " full of " + rank_name(s[2]) + "s";
    case 5:
        return "Flush";
    case 4:
        return std::string("Straight, ") + rank_name(s[1]) + " high";
    case 3:
        return std::string("Three of a kind, ") + rank_name(s[1]) + "s";
    case 2:
        return std::string("Two pair, ") + rank_name(s[1]) + " and " + rank_name(s[2]);
    case 1:
        return std::string("Pair of ") + rank_name(s[1]) + "s";
    default:
        return std::string("High card, ") + rank_name(s[1]) + " kicker";
    }
}

static double score_to_01(const std::array<int, 8> &s)
{
    const double cat = static_cast<double>(s[0]) / 8.0;
    double kick = 0.0;
    for (int i = 1; i < 8; ++i)
        kick += static_cast<double>(s[i]) / (14.0 * static_cast<double>(i));
    kick /= 7.0;
    return std::min(1.0, cat * 0.72 + kick * 0.28);
}

double hand_strength_01(const std::vector<card> &seven_cards)
{
    return score_to_01(best_hand_score(seven_cards));
}

double hand_strength_01_cards(const std::vector<card> &cards)
{
    return score_to_01(detail::best_hand_score_variable(cards));
}
