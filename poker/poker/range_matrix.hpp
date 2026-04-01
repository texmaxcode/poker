#ifndef POKER_RANGE_MATRIX_H
#define POKER_RANGE_MATRIX_H

#include "cards.hpp"

#include <array>
#include <string>

/// 13×13 preflop chart: Ace=row/col 0 … Two=12. Upper triangle (i<j) suited;
/// diagonal pairs; lower triangle (i>j) offsuit.
class RangeMatrix
{
public:
    RangeMatrix();

    double weight(const card &a, const card &b) const;
    void set_cell(int row, int col, double w);
    double cell(int row, int col) const;

    void fill(double v);
    bool parse_text(const std::string &text);
    std::string export_text() const;

    void set_from_flat(const double *data, int count);
    void copy_to_flat(double *out, int count) const;

private:
    std::array<std::array<double, 13>, 13> w_{};
};

int rank_index(Rank r);

#endif
