#include "poker_solver.hpp"

#include "equity_engine.hpp"
#include "range_matrix.hpp"

#include <QMetaObject>
#include <QThreadPool>

#include <cmath>
#include <random>

namespace {

QString normalize_board_line(QString s)
{
    s.replace(QLatin1Char(','), QLatin1Char(' '));
    return s;
}

bool cards_disjoint(const card &a, const card &b, const std::vector<card> &extra)
{
    if (a == b)
        return false;
    for (const auto &c : extra)
    {
        if (a == c || b == c)
            return false;
    }
    return true;
}

QVariantMap compute_equity_impl(const QString &hero1,
                                const QString &hero2,
                                const QString &boardSpaceSeparated,
                                const QString &villainRangeText,
                                const QString &villainExact1,
                                const QString &villainExact2,
                                int iterations,
                                double potBeforeCall,
                                double callAmount)
{
    QVariantMap out;
    card h1, h2;
    if (!parse_card_string(hero1.toStdString(), h1))
    {
        out.insert(QStringLiteral("error"), QStringLiteral("Invalid hero card 1 (use e.g. Ah, Kd, Th)"));
        return out;
    }
    if (!parse_card_string(hero2.toStdString(), h2))
    {
        out.insert(QStringLiteral("error"), QStringLiteral("Invalid hero card 2"));
        return out;
    }
    if (h1 == h2)
    {
        out.insert(QStringLiteral("error"), QStringLiteral("Hero cards must be distinct"));
        return out;
    }

    std::vector<card> board;
    std::string perr;
    if (!parse_board_string(normalize_board_line(boardSpaceSeparated).toStdString(), board, perr))
    {
        out.insert(QStringLiteral("error"), QString::fromStdString(perr));
        return out;
    }

    if (!cards_disjoint(h1, h2, board))
    {
        out.insert(QStringLiteral("error"), QStringLiteral("Board overlaps hero cards"));
        return out;
    }

    RangeMatrix villain_range;
    if (!villainRangeText.trimmed().isEmpty())
    {
        if (!villain_range.parse_text(villainRangeText.toStdString()))
        {
            out.insert(QStringLiteral("error"),
                       QStringLiteral("Could not parse villain range (see Bots tab syntax: AA,AKs,TT+,ATs+)"));
            return out;
        }
    }

    const bool use_exact = !villainExact1.trimmed().isEmpty() && !villainExact2.trimmed().isEmpty();
    card v1, v2;
    if (use_exact)
    {
        if (!parse_card_string(villainExact1.toStdString(), v1) || !parse_card_string(villainExact2.toStdString(), v2))
        {
            out.insert(QStringLiteral("error"), QStringLiteral("Invalid villain exact cards"));
            return out;
        }
        if (v1 == v2)
        {
            out.insert(QStringLiteral("error"), QStringLiteral("Villain cards must be distinct"));
            return out;
        }
        std::vector<card> all = board;
        all.push_back(h1);
        all.push_back(h2);
        all.push_back(v1);
        all.push_back(v2);
        for (size_t i = 0; i < all.size(); ++i)
        {
            for (size_t j = i + 1; j < all.size(); ++j)
            {
                if (all[i] == all[j])
                {
                    out.insert(QStringLiteral("error"),
                               QStringLiteral("Overlapping cards between hero, villain, and board"));
                    return out;
                }
            }
        }
    }

    if (iterations < 1)
        iterations = 5000;
    if (iterations > 5000000)
        iterations = 5000000;

    std::mt19937 rng{std::random_device{}()};
    EquityResult er;
    if (use_exact)
        er = monte_carlo_equity_vs_hand(h1, h2, board, v1, v2, iterations, rng);
    else
        er = monte_carlo_equity_vs_range(h1, h2, board, villain_range, iterations, rng);

    if (!er.error.empty())
    {
        out.insert(QStringLiteral("error"), QString::fromStdString(er.error));
        return out;
    }

    const double eq = er.equity_hero;
    out.insert(QStringLiteral("equity"), eq);
    out.insert(QStringLiteral("equityPct"), eq * 100.0);
    out.insert(QStringLiteral("stdErrPct"), er.std_err * 100.0);
    out.insert(QStringLiteral("iterations"), er.iterations_used);

    QString detail;
    detail += QStringLiteral(
        "Monte Carlo equity (chip expectation from showdown). This is not a full CFR Nash solution for "
        "multi-street play; use commercial solvers (Pio, GTO+, etc.) for precise multi-street strategies.\n\n");
    detail += QStringLiteral("Estimated equity: %1% ± ~%2% (1 std err).\n")
                  .arg(eq * 100.0, 0, 'f', 2)
                  .arg(er.std_err * 100.0, 0, 'f', 2);

    if (potBeforeCall > 0.0 && callAmount > 0.0)
    {
        const double pot = potBeforeCall;
        const double c = callAmount;
        const double be = c / (pot + c);
        out.insert(QStringLiteral("breakEvenEquity"), be);
        out.insert(QStringLiteral("breakEvenPct"), be * 100.0);
        const double ev = eq * (pot + c) - c;
        out.insert(QStringLiteral("evCall"), ev);
        detail += QStringLiteral("\nPot before your call: %1, to call: %2.\n").arg(pot).arg(c);
        detail += QStringLiteral("Break-even equity (chip-EV call vs {win pot+call}): %1%.\n").arg(be * 100.0, 0, 'f', 2);
        detail += QStringLiteral("Chip EV of calling: %1 (if stacks/payouts match this pot model).\n").arg(ev, 0, 'f', 3);
        if (eq > be + 1e-9)
            out.insert(QStringLiteral("recommendation"), QStringLiteral("Call / continue (equity > break-even)"));
        else if (eq < be - 1e-9)
            out.insert(QStringLiteral("recommendation"), QStringLiteral("Fold (equity < break-even)"));
        else
            out.insert(QStringLiteral("recommendation"), QStringLiteral("Indifferent (near break-even)"));
    }
    else
    {
        out.insert(QStringLiteral("recommendation"), QStringLiteral("Enter pot and call amount for chip-EV / pot-odds advice"));
    }

    const double b = callAmount;
    const double p = potBeforeCall;
    if (p > 0 && b > 0)
    {
        const double mdf = p / (p + b);
        out.insert(QStringLiteral("mdfPct"), mdf * 100.0);
        detail += QStringLiteral(
            "\nTeaching note — minimum defense frequency (MDF) vs this raise size, if villain were polarized "
            "and you defended only to stop auto-profit: ~%1% of your continuing range (rough heuristic, not "
            "a full tree solution).\n")
                      .arg(mdf * 100.0, 0, 'f', 1);
    }

    out.insert(QStringLiteral("detailText"), detail);
    return out;
}

} // namespace

PokerSolver::PokerSolver(QObject *parent) : QObject(parent) {}

QVariantMap PokerSolver::computeEquity(const QString &hero1,
                                       const QString &hero2,
                                       const QString &boardSpaceSeparated,
                                       const QString &villainRangeText,
                                       const QString &villainExact1,
                                       const QString &villainExact2,
                                       int iterations,
                                       double potBeforeCall,
                                       double callAmount) const
{
    return compute_equity_impl(hero1, hero2, boardSpaceSeparated, villainRangeText, villainExact1, villainExact2,
                               iterations, potBeforeCall, callAmount);
}

void PokerSolver::computeEquityAsync(const QString &hero1,
                                     const QString &hero2,
                                     const QString &boardSpaceSeparated,
                                     const QString &villainRangeText,
                                     const QString &villainExact1,
                                     const QString &villainExact2,
                                     int iterations,
                                     double potBeforeCall,
                                     double callAmount)
{
    if (async_busy_.exchange(true))
    {
        QVariantMap busy;
        busy.insert(QStringLiteral("error"),
                    QStringLiteral("A simulation is already running. Wait for it to finish."));
        QMetaObject::invokeMethod(
            this,
            [this, busy]() {
                emit equityComputationFinished(busy);
            },
            Qt::QueuedConnection);
        return;
    }

    const QString h1 = hero1;
    const QString h2 = hero2;
    const QString brd = boardSpaceSeparated;
    const QString vr = villainRangeText;
    const QString ve1 = villainExact1;
    const QString ve2 = villainExact2;
    const int iters = iterations;
    const double pot = potBeforeCall;
    const double call = callAmount;

    QThreadPool::globalInstance()->start([=]() {
        QVariantMap r = compute_equity_impl(h1, h2, brd, vr, ve1, ve2, iters, pot, call);
        QMetaObject::invokeMethod(
            this,
            [this, r]() {
                emit equityComputationFinished(r);
                async_busy_.store(false);
            },
            Qt::QueuedConnection);
    });
}
