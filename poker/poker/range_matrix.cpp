#include "range_matrix.hpp"

#include "utils.hpp"

#include <algorithm>
#include <cctype>
#include <sstream>

int rank_index(Rank r)
{
    return 14 - static_cast<int>(r);
}

static Rank char_to_rank(char c)
{
    c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    switch (c)
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

static char rank_to_char(Rank r)
{
    switch (r)
    {
    case Rank::ACE:
        return 'A';
    case Rank::KING:
        return 'K';
    case Rank::QUEEN:
        return 'Q';
    case Rank::JACK:
        return 'J';
    case Rank::TEN:
        return 'T';
    case Rank::NINE:
        return '9';
    case Rank::EIGHT:
        return '8';
    case Rank::SEVEN:
        return '7';
    case Rank::SIX:
        return '6';
    case Rank::FIVE:
        return '5';
    case Rank::FOUR:
        return '4';
    case Rank::THREE:
        return '3';
    case Rank::TWO:
        return '2';
    default:
        return '?';
    }
}

static Rank index_to_rank(int idx)
{
    const int v = 14 - idx;
    return static_cast<Rank>(v);
}

RangeMatrix::RangeMatrix()
{
    fill(1.0);
}

void RangeMatrix::fill(double v)
{
    for (auto &row : w_)
        for (double &x : row)
            x = v;
}

double RangeMatrix::cell(int row, int col) const
{
    if (row < 0 || row > 12 || col < 0 || col > 12)
        return 0.0;
    return w_[static_cast<size_t>(row)][static_cast<size_t>(col)];
}

void RangeMatrix::set_cell(int row, int col, double v)
{
    if (row < 0 || row > 12 || col < 0 || col > 12)
        return;
    w_[static_cast<size_t>(row)][static_cast<size_t>(col)] = std::clamp(v, 0.0, 1.0);
}

double RangeMatrix::weight(const card &a, const card &b) const
{
    const int ia = rank_index(a.rank);
    const int ib = rank_index(b.rank);
    if (ia == ib)
        return w_[static_cast<size_t>(ia)][static_cast<size_t>(ia)];
    const int lo = std::min(ia, ib);
    const int hi = std::max(ia, ib);
    if (a.suite == b.suite)
        return w_[static_cast<size_t>(lo)][static_cast<size_t>(hi)];
    return w_[static_cast<size_t>(hi)][static_cast<size_t>(lo)];
}

void RangeMatrix::set_from_flat(const double *data, int count)
{
    if (count < 169 || !data)
        return;
    int k = 0;
    for (int i = 0; i < 13; ++i)
        for (int j = 0; j < 13; ++j)
            set_cell(i, j, data[k++]);
}

void RangeMatrix::copy_to_flat(double *out, int count) const
{
    if (count < 169 || !out)
        return;
    int k = 0;
    for (int i = 0; i < 13; ++i)
        for (int j = 0; j < 13; ++j)
            out[k++] = w_[static_cast<size_t>(i)][static_cast<size_t>(j)];
}

static void trim_inplace(std::string &s)
{
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.front())))
        s.erase(s.begin());
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back())))
        s.pop_back();
}

bool RangeMatrix::parse_text(const std::string &text)
{
    if (text.find_first_not_of(" \t\n\r") == std::string::npos)
        return true;

    fill(0.0);
    std::stringstream ss(text);
    std::string item;
    bool any = false;
    while (std::getline(ss, item, ','))
    {
        trim_inplace(item);
        if (item.empty())
            continue;
        any = true;

        if (item.size() >= 3 && item.back() == '+')
        {
            std::string base = item.substr(0, item.size() - 1);
            trim_inplace(base);
            if (base.size() == 2 && base[0] == base[1])
            {
                const int idx = rank_index(char_to_rank(base[0]));
                for (int i = 0; i <= idx; ++i)
                    set_cell(i, i, 1.0);
                continue;
            }
            if (base.size() == 3 && (base[2] == 's' || base[2] == 'S'))
            {
                const int ia = rank_index(char_to_rank(base[0]));
                const int ib = rank_index(char_to_rank(base[1]));
                const int hi = std::min(ia, ib);
                const int lo = std::max(ia, ib);
                if (hi == lo)
                    return false;
                for (int j = lo; j > hi; --j)
                    set_cell(hi, j, 1.0);
                continue;
            }
            return false;
        }

        if (item.size() == 2 && item[0] == item[1])
        {
            const int idx = rank_index(char_to_rank(item[0]));
            set_cell(idx, idx, 1.0);
            continue;
        }

        if (item.size() == 3)
        {
            const int ia = rank_index(char_to_rank(item[0]));
            const int ib = rank_index(char_to_rank(item[1]));
            const int hi = std::min(ia, ib);
            const int lo = std::max(ia, ib);
            if (hi == lo)
                return false;
            const char t = static_cast<char>(std::tolower(static_cast<unsigned char>(item[2])));
            if (t == 's')
                set_cell(hi, lo, 1.0);
            else if (t == 'o')
                set_cell(lo, hi, 1.0);
            else
                return false;
            continue;
        }

        return false;
    }
    return any;
}

std::string RangeMatrix::export_text() const
{
    std::ostringstream o;
    bool first = true;
    for (int i = 0; i < 13; ++i)
    {
        for (int j = 0; j < 13; ++j)
        {
            const double v = w_[static_cast<size_t>(i)][static_cast<size_t>(j)];
            if (v < 0.5)
                continue;
            if (!first)
                o << ',';
            first = false;
            if (i == j)
            {
                const char c = rank_to_char(index_to_rank(i));
                o << c << c;
            }
            else if (i < j)
            {
                o << rank_to_char(index_to_rank(i)) << rank_to_char(index_to_rank(j)) << 's';
            }
            else
            {
                o << rank_to_char(index_to_rank(j)) << rank_to_char(index_to_rank(i)) << 'o';
            }
        }
    }
    return o.str();
}
