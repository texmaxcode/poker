#include "toy_nash_solver.hpp"

#include <QMetaObject>
#include <QThreadPool>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdio>
#include <random>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace {

struct InfoNode
{
    // CFR+ uses regret-matching with non-negative regrets.
    std::vector<double> regret_sum;
    std::vector<double> strategy_sum;

    explicit InfoNode(int actions = 0) : regret_sum(actions, 0.0), strategy_sum(actions, 0.0) {}
};

std::vector<double> regret_matching_plus(const std::vector<double> &regret_sum)
{
    const int n = static_cast<int>(regret_sum.size());
    std::vector<double> strat(static_cast<size_t>(n), 0.0);
    double normalizer = 0.0;
    for (int a = 0; a < n; ++a)
    {
        const double r = std::max(0.0, regret_sum[static_cast<size_t>(a)]);
        strat[static_cast<size_t>(a)] = r;
        normalizer += r;
    }
    if (normalizer <= 0.0)
    {
        const double u = 1.0 / std::max(1, n);
        for (int a = 0; a < n; ++a)
            strat[static_cast<size_t>(a)] = u;
        return strat;
    }
    for (int a = 0; a < n; ++a)
        strat[static_cast<size_t>(a)] /= normalizer;
    return strat;
}

std::string fmt_prob(double p)
{
    const double x = std::clamp(p * 100.0, 0.0, 100.0);
    char buf[32];
    std::snprintf(buf, sizeof(buf), "%.1f%%", x);
    return std::string(buf);
}

// -------------------------
// Kuhn poker (3-card)
// Actions at each decision: 0=check/call, 1=bet/fold depending on node.
// History encoding:
// "" start
// "c" P0 checks, "b" P0 bets
// "cc" showdown, "cb" P1 bets, "bc" P1 calls, "bf" P1 folds, "cbc" P0 calls, "cbf" P0 folds
// -------------------------

constexpr std::array<int, 3> kKuhnDeck = {0, 1, 2}; // J,Q,K ascending

bool kuhn_terminal(const std::string &h)
{
    return h == "cc" || h == "bc" || h == "bf" || h == "cbc" || h == "cbf";
}

int kuhn_pot(const std::string &h)
{
    // Both ante 1.
    if (h == "cc")
        return 2;
    if (h == "bf")
        return 3; // P1 folded to bet
    if (h == "bc")
        return 4;
    if (h == "cbf")
        return 3;
    if (h == "cbc")
        return 4;
    return 2;
}

double kuhn_payoff_p0(const std::array<int, 2> &cards, const std::string &h)
{
    // Payoff from P0 perspective, in chips.
    // Antes: both put 1.
    if (h == "bf")
        return +1; // P1 folds; P0 wins pot 3, invested 2 -> +1
    if (h == "cbf")
        return -1; // P0 folds after P1 bet; loses his ante

    const int pot = kuhn_pot(h);
    const bool p0_wins = cards[0] > cards[1];
    // Investment:
    // If no one bet: each invested 1.
    // If bet/call line: bettor+caller invested 2 each.
    const int invest = (h == "cc") ? 1 : 2;
    if (p0_wins)
        return pot - invest;
    return -invest;
}

std::string kuhn_infoset_key(int player, const std::array<int, 2> &cards, const std::string &h)
{
    // card + history, standard Kuhn formulation
    const int c = cards[static_cast<size_t>(player)];
    const char card_char = (c == 0) ? 'J' : (c == 1 ? 'Q' : 'K');
    return std::string(1, card_char) + ":" + h;
}

double kuhn_cfr(std::unordered_map<std::string, InfoNode> &nodes,
                const std::array<int, 2> &cards,
                const std::string &history,
                int player,
                double p0,
                double p1)
{
    if (kuhn_terminal(history))
        return kuhn_payoff_p0(cards, history);

    const int current_player = static_cast<int>(history.size() % 2);
    const std::string key = kuhn_infoset_key(current_player, cards, history);
    auto it = nodes.find(key);
    if (it == nodes.end())
        it = nodes.emplace(key, InfoNode(2)).first;

    InfoNode &node = it->second;
    const std::vector<double> strategy = regret_matching_plus(node.regret_sum);

    // Accumulate average strategy with reach prob for this infoset player
    const double reach = (current_player == 0) ? p0 : p1;
    for (int a = 0; a < 2; ++a)
        node.strategy_sum[static_cast<size_t>(a)] += reach * strategy[static_cast<size_t>(a)];

    std::array<double, 2> util{};
    double node_util = 0.0;
    for (int a = 0; a < 2; ++a)
    {
        std::string next = history;
        // Action mapping depends on history context:
        // At start or after check: action0='c' (check/call), action1='b' (bet)
        // After a bet: action0='c' (call), action1='f' (fold)
        const bool facing_bet = (!history.empty() && history.back() == 'b');
        if (!facing_bet)
            next.push_back(a == 0 ? 'c' : 'b');
        else
            next.push_back(a == 0 ? 'c' : 'f');

        if (current_player == 0)
            util[static_cast<size_t>(a)] = kuhn_cfr(nodes, cards, next, player, p0 * strategy[a], p1);
        else
            util[static_cast<size_t>(a)] = kuhn_cfr(nodes, cards, next, player, p0, p1 * strategy[a]);

        node_util += strategy[static_cast<size_t>(a)] * util[static_cast<size_t>(a)];
    }

    // CFR+ regret update for current player's infoset.
    for (int a = 0; a < 2; ++a)
    {
        const double regret = util[static_cast<size_t>(a)] - node_util;
        const double opp_reach = (current_player == 0) ? p1 : p0;
        node.regret_sum[static_cast<size_t>(a)] =
            std::max(0.0, node.regret_sum[static_cast<size_t>(a)] + opp_reach * regret);
    }

    return node_util;
}

QVariantMap solve_kuhn_impl(int iterations)
{
    QVariantMap out;
    if (iterations < 1)
        iterations = 1000;
    iterations = std::min(iterations, 5'000'000);

    std::unordered_map<std::string, InfoNode> nodes;
    nodes.reserve(64);

    // CFR+ with chance sampling over the 6 private deals.
    double ev = 0.0;
    for (int t = 0; t < iterations; ++t)
    {
        for (int i = 0; i < 3; ++i)
        {
            for (int j = 0; j < 3; ++j)
            {
                if (i == j)
                    continue;
                const std::array<int, 2> cards = {kKuhnDeck[static_cast<size_t>(i)],
                                                  kKuhnDeck[static_cast<size_t>(j)]};
                ev += kuhn_cfr(nodes, cards, "", 0, 1.0, 1.0);
            }
        }
    }
    // Average across iterations and deals.
    const double denom = static_cast<double>(iterations) * 6.0;
    ev /= denom;

    // Build a readable strategy summary (average strategy).
    std::string strat;
    auto dump = [&](char card) {
        // keys: "J:" etc with histories "", "c", "b", "cb"
        const std::array<std::string, 4> hs = {"", "c", "b", "cb"};
        for (const auto &h : hs)
        {
            const std::string key = std::string(1, card) + ":" + h;
            auto it = nodes.find(key);
            if (it == nodes.end())
                continue;
            const auto &n = it->second;
            const double s0 = n.strategy_sum[0];
            const double s1 = n.strategy_sum[1];
            const double z = s0 + s1;
            const double p_check = (z > 0) ? (s0 / z) : 0.5;
            const double p_bet = (z > 0) ? (s1 / z) : 0.5;
            strat += card;
            strat += " @ ";
            strat += (h.empty() ? "start" : h);
            strat += ": ";
            strat += "A0=" + fmt_prob(p_check) + " A1=" + fmt_prob(p_bet) + "\n";
        }
    };
    strat += "Kuhn average strategy (A0=check/call, A1=bet/fold):\n";
    dump('J');
    dump('Q');
    dump('K');

    out.insert(QStringLiteral("game"), QStringLiteral("Kuhn"));
    out.insert(QStringLiteral("iterations"), iterations);
    out.insert(QStringLiteral("evP0"), ev);
    out.insert(QStringLiteral("summaryText"),
               QStringLiteral("Solved Kuhn with CFR+.\nEV(P0) ≈ %1 (chips/hand).")
                   .arg(ev, 0, 'f', 4));
    out.insert(QStringLiteral("detailText"), QString::fromStdString(strat));
    return out;
}

// -------------------------
// Leduc hold'em (toy): 2 ranks × 3 suits = 6 cards.
// Each player gets 1 private card; one public card is revealed after first betting round.
// Betting: fixed-limit with 2 actions at each node:
// - If no bet yet: check or bet (1 on round1, 2 on round2)
// - If bet: call or fold (single bet per round; no raises in this tiny variant)
// -------------------------

constexpr std::array<int, 6> kLeducDeck = {0, 0, 0, 1, 1, 1}; // ranks only (J=0, Q=1)

struct LeducState
{
    int p0_idx = -1;
    int p1_idx = -1;
    int p0_rank = -1;
    int p1_rank = -1;
    int pub_rank = -1; // public rank or -1 preflop
    int round = 0; // 0=pre, 1=post
    int to_act = 0; // whose turn in this betting round
    bool bet_made = false; // bet pending response in this round
    std::string rhist; // current-round history only: "", "x", "b", "xx", "bc"; "bf" is terminal fold
    int pot = 0;
    int contrib0 = 0;
    int contrib1 = 0;
};

int leduc_winner(const LeducState &s)
{
    // Pair beats high card; if both pair or both high, higher rank wins (Q>J). Ties split.
    const bool p0_pair = (s.pub_rank >= 0 && s.p0_rank == s.pub_rank);
    const bool p1_pair = (s.pub_rank >= 0 && s.p1_rank == s.pub_rank);
    if (p0_pair && !p1_pair)
        return 0;
    if (p1_pair && !p0_pair)
        return 1;
    if (s.p0_rank > s.p1_rank)
        return 0;
    if (s.p1_rank > s.p0_rank)
        return 1;
    return -1;
}

std::string leduc_infoset_key(int player, const LeducState &s)
{
    const int priv_rank = (player == 0 ? s.p0_rank : s.p1_rank);
    const char priv = (priv_rank == 0 ? 'J' : 'Q');
    const char pub = (s.pub_rank < 0 ? 'X' : (s.pub_rank == 0 ? 'J' : 'Q'));
    std::string k;
    k.reserve(24 + s.rhist.size());
    k.push_back(priv);
    k.push_back('/');
    k.push_back(pub);
    k += (s.round == 0 ? ":pre:" : ":post:");
    k += (s.bet_made ? "b:" : "n:");
    k += s.rhist;
    return k;
}

bool leduc_round_closed(const LeducState &s)
{
    // Close the round when:
    // - both checked ("xx"), or
    // - a bet was called (history ends with 'c' and bet is no longer pending).
    if (s.rhist == "xx")
        return true;
    if (!s.rhist.empty() && s.rhist.back() == 'c' && !s.bet_made)
        return true;
    return false;
}

double leduc_payoff_p0_showdown(const LeducState &s)
{
    const int w = leduc_winner(s);
    if (w == -1)
        return 0.0;
    if (w == 0)
        return static_cast<double>(s.pot - s.contrib0);
    return static_cast<double>(-s.contrib0);
}

double leduc_cfr(std::unordered_map<std::string, InfoNode> &nodes,
                 LeducState s,
                 double p0,
                 double p1)
{
    // Basic sanity: ranks must be set once cards are dealt.
    if (s.p0_rank < 0 || s.p1_rank < 0)
        return 0.0;
    // Terminal: fold ends the hand immediately (fold is always a response to a bet).
    if (!s.rhist.empty() && s.rhist.back() == 'f')
    {
        // The folder is the current player who just acted with 'f'.
        const int folder = s.to_act;
        const int winner = 1 - folder;
        if (winner == 0)
            return static_cast<double>(s.pot - s.contrib0);
        return static_cast<double>(-s.contrib0);
    }

    // Round close transitions (chance / showdown).
    if (leduc_round_closed(s))
    {
        if (s.round == 0)
        {
            double ev = 0.0;
            int count = 0;
            for (int k = 0; k < 6; ++k)
            {
                if (k == s.p0_idx || k == s.p1_idx)
                    continue;
                LeducState ns = s;
                ns.pub_rank = kLeducDeck[static_cast<size_t>(k)];
                ns.round = 1;
                ns.to_act = 0;
                ns.bet_made = false;
                ns.rhist.clear();
                ev += leduc_cfr(nodes, ns, p0, p1);
                ++count;
            }
            return (count > 0) ? ev / count : 0.0;
        }
        return leduc_payoff_p0_showdown(s);
    }

    const int current_player = s.to_act;
    const std::string key = leduc_infoset_key(current_player, s);
    auto it = nodes.find(key);
    if (it == nodes.end())
        it = nodes.emplace(key, InfoNode(2)).first;
    InfoNode &node = it->second;
    const std::vector<double> strategy = regret_matching_plus(node.regret_sum);

    const double reach = (current_player == 0) ? p0 : p1;
    node.strategy_sum[0] += reach * strategy[0];
    node.strategy_sum[1] += reach * strategy[1];

    const bool facing_bet = s.bet_made;
    std::array<double, 2> util{};
    double node_util = 0.0;
    for (int a = 0; a < 2; ++a)
    {
        LeducState ns = s;
        const int bet_size = (ns.round == 0 ? 1 : 2);
        if (!facing_bet)
        {
            if (a == 0)
            {
                ns.rhist.push_back('x');
                ns.to_act = 1 - ns.to_act;
            }
            else
            {
                ns.rhist.push_back('b');
                ns.bet_made = true;
                if (current_player == 0)
                {
                    ns.contrib0 += bet_size;
                    ns.pot += bet_size;
                }
                else
                {
                    ns.contrib1 += bet_size;
                    ns.pot += bet_size;
                }
                ns.to_act = 1 - ns.to_act;
            }
        }
        else
        {
            if (a == 0)
            {
                ns.rhist.push_back('c');
                ns.bet_made = false;
                if (current_player == 0)
                {
                    ns.contrib0 += bet_size;
                    ns.pot += bet_size;
                }
                else
                {
                    ns.contrib1 += bet_size;
                    ns.pot += bet_size;
                }
                ns.to_act = 1 - ns.to_act;
            }
            else
            {
                ns.bet_made = false;
                ns.rhist.push_back('f');
                ns.to_act = current_player; // folding player (for terminal payoff)
            }
        }

        if (current_player == 0)
            util[a] = leduc_cfr(nodes, ns, p0 * strategy[a], p1);
        else
            util[a] = leduc_cfr(nodes, ns, p0, p1 * strategy[a]);
        node_util += strategy[a] * util[a];
    }

    for (int a = 0; a < 2; ++a)
    {
        const double regret = util[a] - node_util;
        const double opp = (current_player == 0) ? p1 : p0;
        node.regret_sum[a] = std::max(0.0, node.regret_sum[a] + opp * regret);
    }

    return node_util;
}

QVariantMap solve_leduc_impl(int iterations)
{
    QVariantMap out;
    if (iterations < 1)
        iterations = 1000;
    iterations = std::min(iterations, 2'000'000);

    std::unordered_map<std::string, InfoNode> nodes;
    nodes.reserve(4096);

    double ev = 0.0;
    int deals = 0;
    // Enumerate distinct private deals for exact chance instead of sampling; keep iterations as CFR passes.
    std::vector<std::pair<int, int>> priv_deals;
    for (int i = 0; i < 6; ++i)
    {
        for (int j = 0; j < 6; ++j)
        {
            if (i == j)
                continue;
            priv_deals.emplace_back(i, j);
        }
    }

    for (int t = 0; t < iterations; ++t)
    {
        for (const auto &d : priv_deals)
        {
            LeducState s;
            s.p0_idx = d.first;
            s.p1_idx = d.second;
            s.p0_rank = kLeducDeck[static_cast<size_t>(s.p0_idx)];
            s.p1_rank = kLeducDeck[static_cast<size_t>(s.p1_idx)];
            s.pub_rank = -1;
            s.round = 0;
            s.to_act = 0;
            s.bet_made = false;
            s.rhist.clear();
            s.pot = 2;
            s.contrib0 = 1;
            s.contrib1 = 1;
            ev += leduc_cfr(nodes, s, 1.0, 1.0);
            ++deals;
        }
    }
    ev /= std::max(1, deals);

    // Strategy dump (coarse): show root strategies by private card.
    auto avg = [&](const std::string &k) {
        auto it = nodes.find(k);
        if (it == nodes.end())
            return std::pair<double, double>(0.5, 0.5);
        const auto &n = it->second;
        const double z = n.strategy_sum[0] + n.strategy_sum[1];
        if (z <= 0)
            return std::pair<double, double>(0.5, 0.5);
        return std::pair<double, double>(n.strategy_sum[0] / z, n.strategy_sum[1] / z);
    };

    std::string detail;
    detail += "Leduc average strategy (A0=check/call, A1=bet/fold). Root (private/public unknown):\n";
    // root infosets use pub='X', pre, no bet, history=""
    for (char priv : {'J', 'Q'})
    {
        const std::string k = std::string(1, priv) + "/X:pre:n:";
        const auto [a0, a1] = avg(k);
        detail += priv;
        detail += " @ preflop: A0=" + fmt_prob(a0) + " A1=" + fmt_prob(a1) + "\n";
    }

    out.insert(QStringLiteral("game"), QStringLiteral("Leduc"));
    out.insert(QStringLiteral("iterations"), iterations);
    out.insert(QStringLiteral("evP0"), ev);
    out.insert(QStringLiteral("summaryText"),
               QStringLiteral("Solved Leduc (toy) with CFR+.\nEV(P0) ≈ %1 (arbitrary units).")
                   .arg(ev, 0, 'f', 4));
    out.insert(QStringLiteral("detailText"), QString::fromStdString(detail));
    return out;
}

} // namespace

ToyNashSolver::ToyNashSolver(QObject *parent) : QObject(parent) {}

QVariantMap ToyNashSolver::solveKuhn(int iterations) const
{
    return solve_kuhn_impl(iterations);
}

void ToyNashSolver::solveKuhnAsync(int iterations)
{
    if (async_busy_.exchange(true))
        return;
    QThreadPool::globalInstance()->start([this, iterations]() {
        const QVariantMap r = solve_kuhn_impl(iterations);
        QMetaObject::invokeMethod(this, [this, r]() {
            async_busy_.store(false);
            emit solveFinished(r);
        });
    });
}

QVariantMap ToyNashSolver::solveLeduc(int iterations) const
{
    return solve_leduc_impl(iterations);
}

void ToyNashSolver::solveLeducAsync(int iterations)
{
    if (async_busy_.exchange(true))
        return;
    QThreadPool::globalInstance()->start([this, iterations]() {
        const QVariantMap r = solve_leduc_impl(iterations);
        QMetaObject::invokeMethod(this, [this, r]() {
            async_busy_.store(false);
            emit solveFinished(r);
        });
    });
}

