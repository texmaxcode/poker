#include "game_persistence.hpp"

#include "game.hpp"
#include "persist_sqlite.hpp"

#include <algorithm>

#include <QDateTime>
#include <QString>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>

namespace {

constexpr int kMaxBankrollSnapshotsPersisted = 8000;

int clamp_int(int v, int lo, int hi)
{
    return std::max(lo, std::min(hi, v));
}

} // namespace

GamePersistence::GamePersistence(game &g)
    : game_(g)
{
}

void GamePersistence::save_bankroll_session_to_settings() const
{
    const size_t n = game_.bankroll_tracker_.bankroll_history_.size();
    const size_t start =
        (n > static_cast<size_t>(kMaxBankrollSnapshotsPersisted))
            ? (n - static_cast<size_t>(kMaxBankrollSnapshotsPersisted))
            : 0;
    QVariantList histList;
    QVariantList timesList;
    for (size_t r = start; r < n; ++r)
    {
        QVariantList row;
        for (int i = 0; i < game::kMaxPlayers; ++i)
            row.append(game_.bankroll_tracker_.bankroll_history_[r][static_cast<size_t>(i)]);
        histList.append(row);
        timesList.append(static_cast<qlonglong>(game_.bankroll_tracker_.bankroll_snapshot_times_ms_[r]));
    }
    AppStateSqlite::setValue(QStringLiteral("v1/bankrollHistory"), histList);
    AppStateSqlite::setValue(QStringLiteral("v1/bankrollSnapshotTimesMs"), timesList);
    QVariantList baselineList;
    for (int i = 0; i < game::kMaxPlayers; ++i)
        baselineList.append(game_.bankroll_tracker_.session_baseline_[static_cast<size_t>(i)]);
    AppStateSqlite::setValue(QStringLiteral("v1/sessionBaseline"), baselineList);
}

bool GamePersistence::load_bankroll_session_from_settings()
{
    const QVariant vh = AppStateSqlite::value(QStringLiteral("v1/bankrollHistory"));
    const QVariant vt = AppStateSqlite::value(QStringLiteral("v1/bankrollSnapshotTimesMs"));
    if (!vh.canConvert<QVariantList>() || !vt.canConvert<QVariantList>())
        return false;
    const QVariantList histOuter = vh.toList();
    const QVariantList timesList = vt.toList();
    if (histOuter.isEmpty())
        return false;

    std::vector<std::array<int, game::kMaxPlayers>> loaded_hist;
    std::vector<qint64> loaded_times;

    const QVariant &v0 = histOuter[0];
    if (v0.canConvert<QVariantList>())
    {
        const QVariantList row0 = v0.toList();
        if (row0.size() >= game::kMaxPlayers)
        {
            for (int r = 0; r < histOuter.size(); ++r)
            {
                const QVariantList row = histOuter[r].toList();
                if (row.size() < game::kMaxPlayers)
                    return false;
                std::array<int, game::kMaxPlayers> snap{};
                for (int i = 0; i < game::kMaxPlayers; ++i)
                    snap[static_cast<size_t>(i)] =
                        clamp_int(static_cast<int>(row[i].toDouble()), 0, 1000000000);
                loaded_hist.push_back(snap);
            }
            const int rows = static_cast<int>(loaded_hist.size());
            loaded_times.reserve(static_cast<size_t>(rows));
            for (int r = 0; r < rows; ++r)
            {
                qint64 t = 0;
                if (r < timesList.size())
                    t = timesList[r].toLongLong();
                else if (!timesList.isEmpty())
                    t = timesList.last().toLongLong();
                else
                    t = QDateTime::currentMSecsSinceEpoch();
                loaded_times.push_back(t);
            }
        }
    }

    if (loaded_hist.empty())
    {
        if (histOuter.size() % game::kMaxPlayers != 0)
            return false;
        const int rows = static_cast<int>(histOuter.size() / game::kMaxPlayers);
        loaded_hist.reserve(static_cast<size_t>(rows));
        for (int r = 0; r < rows; ++r)
        {
            std::array<int, game::kMaxPlayers> snap{};
            for (int i = 0; i < game::kMaxPlayers; ++i)
                snap[static_cast<size_t>(i)] = clamp_int(
                    static_cast<int>(histOuter[r * game::kMaxPlayers + i].toDouble()), 0, 1000000000);
            loaded_hist.push_back(snap);
        }
        loaded_times.reserve(static_cast<size_t>(rows));
        for (int r = 0; r < rows; ++r)
        {
            qint64 t = 0;
            if (r < timesList.size())
                t = timesList[r].toLongLong();
            else if (!timesList.isEmpty())
                t = timesList.last().toLongLong();
            else
                t = QDateTime::currentMSecsSinceEpoch();
            loaded_times.push_back(t);
        }
    }

    if (loaded_hist.empty())
        return false;

    game_.bankroll_tracker_.bankroll_history_ = std::move(loaded_hist);
    game_.bankroll_tracker_.bankroll_snapshot_times_ms_ = std::move(loaded_times);

    const QVariant vb = AppStateSqlite::value(QStringLiteral("v1/sessionBaseline"));
    if (vb.canConvert<QVariantList>())
    {
        const QVariantList bl = vb.toList();
        if (bl.size() >= game::kMaxPlayers)
        {
            for (int i = 0; i < game::kMaxPlayers; ++i)
                game_.bankroll_tracker_.session_baseline_[static_cast<size_t>(i)] =
                    clamp_int(static_cast<int>(bl[i].toDouble()), 0, 1000000000);
        }
    }
    else
    {
        const int n = game_.players_count();
        for (int i = 0; i < n; ++i)
            game_.bankroll_tracker_.session_baseline_[static_cast<size_t>(i)] =
                game_.table[static_cast<size_t>(i)].stack + game_.seat_mgr_.seat_wallet_[static_cast<size_t>(i)];
    }

    game_.bankroll_tracker_.notifySessionStatsChanged();
    return true;
}

void GamePersistence::loadPersistedSettings()
{
    if (!AppStateSqlite::isOpen())
        return;

    game_.suppress_persist_ = true;

    if (AppStateSqlite::contains(QStringLiteral("v1/smallBlind")))
    {
        const int sb = clamp_int(AppStateSqlite::value(QStringLiteral("v1/smallBlind")).toInt(), 1, 500);
        const int bb = clamp_int(AppStateSqlite::value(QStringLiteral("v1/bigBlind")).toInt(), 1, 500);
        const int st = clamp_int(AppStateSqlite::value(QStringLiteral("v1/streetBet")).toInt(), 1, 100000);
        const int stack = clamp_int(AppStateSqlite::value(QStringLiteral("v1/startStack")).toInt(), 20, 1000000);
        game_.configureImpl(sb, bb, st, stack, false);

        const int cap = game_.maxBuyInChips();
        for (int i = 0; i < game::kMaxPlayers; ++i)
        {
            const QString bik = QStringLiteral("v1/seat%1/buyIn").arg(i);
            if (AppStateSqlite::contains(bik))
                game_.seat_mgr_.seat_buy_in_[static_cast<size_t>(i)] = clamp_int(AppStateSqlite::value(bik).toInt(), 1, cap);
            else
                game_.seat_mgr_.seat_buy_in_[static_cast<size_t>(i)] = std::min(stack, cap);
        }
        for (int i = 0; i < game::kMaxPlayers; ++i)
        {
            const QString wk = QStringLiteral("v1/seat%1/wallet").arg(i);
            if (AppStateSqlite::contains(wk))
                game_.seat_mgr_.seat_wallet_[static_cast<size_t>(i)] = clamp_int(AppStateSqlite::value(wk).toInt(), 0, 100000000);
        }
        game_.seat_mgr_.apply_seat_buy_ins_to_table(false);
    }
    else
    {
        if (AppStateSqlite::contains(QStringLiteral("v1/bigBlind")))
            game_.big_blind = clamp_int(AppStateSqlite::value(QStringLiteral("v1/bigBlind")).toInt(), 1, 500);
        if (AppStateSqlite::contains(QStringLiteral("v1/streetBet")))
            game_.street_bet_ = clamp_int(AppStateSqlite::value(QStringLiteral("v1/streetBet")).toInt(), 1, 100000);
        if (AppStateSqlite::contains(QStringLiteral("v1/startStack")))
            game_.starting_stack_ = clamp_int(AppStateSqlite::value(QStringLiteral("v1/startStack")).toInt(), 20, 1000000);

        const int cap = game_.maxBuyInChips();
        for (int i = 0; i < game::kMaxPlayers; ++i)
        {
            const QString bik = QStringLiteral("v1/seat%1/buyIn").arg(i);
            if (AppStateSqlite::contains(bik))
                game_.seat_mgr_.seat_buy_in_[static_cast<size_t>(i)] = clamp_int(AppStateSqlite::value(bik).toInt(), 1, cap);
            const QString wk = QStringLiteral("v1/seat%1/wallet").arg(i);
            if (AppStateSqlite::contains(wk))
                game_.seat_mgr_.seat_wallet_[static_cast<size_t>(i)] = clamp_int(AppStateSqlite::value(wk).toInt(), 0, 100000000);
        }
        game_.seat_mgr_.apply_seat_buy_ins_to_table(false);
    }

    const bool bankrollLoaded = load_bankroll_session_from_settings();
    if (!bankrollLoaded)
        game_.bankroll_tracker_.init_bankroll_after_configure();

    const int stratMax = static_cast<int>(BotStrategy::Count) - 1;
    for (int i = 0; i < game::kMaxPlayers; ++i)
    {
        const QString sidx = QStringLiteral("v1/seat%1/strategy").arg(i);
        const int strat = clamp_int(AppStateSqlite::value(sidx).toInt(), 0, stratMax);
        game_.setSeatStrategy(i, strat);
        const QString rt = AppStateSqlite::value(QStringLiteral("v1/seat%1/rangeText").arg(i)).toString();
        if (!rt.isEmpty())
            game_.applySeatRangeText(i, rt, 0);
        const QString rtr = AppStateSqlite::value(QStringLiteral("v1/seat%1/rangeTextRaise").arg(i)).toString();
        const QString rtb = AppStateSqlite::value(QStringLiteral("v1/seat%1/rangeTextBet").arg(i)).toString();
        SeatBot &sb = game_.seat_cfg_[static_cast<size_t>(i)];
        if (!rtr.isEmpty())
            game_.applySeatRangeText(i, rtr, 1);
        else
            sb.range_raise = sb.range_call;
        if (!rtb.isEmpty())
            game_.applySeatRangeText(i, rtb, 2);
        else
            sb.range_bet = sb.range_call;

        const QString pfx = QStringLiteral("v1/seat%1/").arg(i);
        QVariantMap pm;
        if (AppStateSqlite::contains(pfx + QStringLiteral("preflopExponent")))
            pm.insert(QStringLiteral("preflopExponent"), AppStateSqlite::value(pfx + QStringLiteral("preflopExponent")));
        if (AppStateSqlite::contains(pfx + QStringLiteral("postflopExponent")))
            pm.insert(QStringLiteral("postflopExponent"), AppStateSqlite::value(pfx + QStringLiteral("postflopExponent")));
        if (AppStateSqlite::contains(pfx + QStringLiteral("facingRaiseBonus")))
            pm.insert(QStringLiteral("facingRaiseBonus"), AppStateSqlite::value(pfx + QStringLiteral("facingRaiseBonus")));
        if (AppStateSqlite::contains(pfx + QStringLiteral("facingRaiseTightMul")))
            pm.insert(QStringLiteral("facingRaiseTightMul"), AppStateSqlite::value(pfx + QStringLiteral("facingRaiseTightMul")));
        if (AppStateSqlite::contains(pfx + QStringLiteral("openBetBonus")))
            pm.insert(QStringLiteral("openBetBonus"), AppStateSqlite::value(pfx + QStringLiteral("openBetBonus")));
        if (AppStateSqlite::contains(pfx + QStringLiteral("openBetTightMul")))
            pm.insert(QStringLiteral("openBetTightMul"), AppStateSqlite::value(pfx + QStringLiteral("openBetTightMul")));
        if (AppStateSqlite::contains(pfx + QStringLiteral("bbCheckraiseBonus")))
            pm.insert(QStringLiteral("bbCheckraiseBonus"), AppStateSqlite::value(pfx + QStringLiteral("bbCheckraiseBonus")));
        if (AppStateSqlite::contains(pfx + QStringLiteral("bbCheckraiseTightMul")))
            pm.insert(QStringLiteral("bbCheckraiseTightMul"), AppStateSqlite::value(pfx + QStringLiteral("bbCheckraiseTightMul")));
        if (!pm.isEmpty())
            game_.setSeatStrategyParams(i, pm);
    }

    game_.setHumanSitOut(AppStateSqlite::value(QStringLiteral("v1/humanSitOut"), false).toBool());
    game_.setInteractiveHuman(AppStateSqlite::value(QStringLiteral("v1/interactiveHuman"), true).toBool());
    if (!game_.interactive_human_)
        game_.setHumanSitOut(false);
    game_.setBotSlowActions(AppStateSqlite::value(QStringLiteral("v1/botSlowActions"), false).toBool());
    for (int s = 1; s < game::kMaxPlayers; ++s)
    {
        const bool def = true;
        game_.setSeatParticipating(s,
                             AppStateSqlite::value(QStringLiteral("v1/seat%1/participating").arg(s), def).toBool());
    }
    game_.suppress_persist_ = false;
    game_.persist_loaded_ = true;
    emit game_.interactiveHumanChanged();
}

void GamePersistence::savePersistedSettings() const
{
    writePersistedSettingsImpl(false);
}

void GamePersistence::seedMissingPersistedSettings() const
{
    writePersistedSettingsImpl(true);
}

void GamePersistence::writePersistedSettingsImpl(bool onlyIfMissingKeys) const
{
    if (!AppStateSqlite::isOpen())
        return;
    if (!game_.persist_loaded_)
    {
        qWarning() << "savePersistedSettings called before load completed — skipping";
        return;
    }
    AppStateSqlite::beginTransaction();
    auto put = [onlyIfMissingKeys](const QString &key, const QVariant &val) {
        if (onlyIfMissingKeys && AppStateSqlite::contains(key))
            return;
        AppStateSqlite::setValue(key, val);
    };

    put(QStringLiteral("v1/smallBlind"), game_.small_blind);
    put(QStringLiteral("v1/bigBlind"), game_.big_blind);
    put(QStringLiteral("v1/streetBet"), game_.street_bet_);
    put(QStringLiteral("v1/startStack"), game_.starting_stack_);
    put(QStringLiteral("v1/humanSitOut"), game_.human_sitting_out_);
    put(QStringLiteral("v1/interactiveHuman"), game_.interactive_human_);
    put(QStringLiteral("v1/botSlowActions"), game_.bot_slow_actions_);
    for (int s = 1; s < game::kMaxPlayers; ++s)
        put(QStringLiteral("v1/seat%1/participating").arg(s),
            game_.seat_mgr_.seat_participating_[static_cast<size_t>(s)]);

    for (int i = 0; i < game::kMaxPlayers; ++i)
    {
        put(QStringLiteral("v1/seat%1/strategy").arg(i), game_.seatStrategyIndex(i));
        put(QStringLiteral("v1/seat%1/rangeText").arg(i), game_.exportSeatRangeText(i, 0));
        put(QStringLiteral("v1/seat%1/rangeTextRaise").arg(i), game_.exportSeatRangeText(i, 1));
        put(QStringLiteral("v1/seat%1/rangeTextBet").arg(i), game_.exportSeatRangeText(i, 2));
        put(QStringLiteral("v1/seat%1/buyIn").arg(i), game_.seat_mgr_.seat_buy_in_[static_cast<size_t>(i)]);
        put(QStringLiteral("v1/seat%1/wallet").arg(i), game_.seat_mgr_.seat_wallet_[static_cast<size_t>(i)]);
        const BotParams &bp = game_.seat_cfg_[static_cast<size_t>(i)].params;
        const QString pfx = QStringLiteral("v1/seat%1/").arg(i);
        put(pfx + QStringLiteral("preflopExponent"), bp.preflop_exponent);
        put(pfx + QStringLiteral("postflopExponent"), bp.postflop_exponent);
        put(pfx + QStringLiteral("facingRaiseBonus"), bp.facing_raise_bonus);
        put(pfx + QStringLiteral("facingRaiseTightMul"), bp.facing_raise_tight_mul);
        put(pfx + QStringLiteral("openBetBonus"), bp.open_bet_bonus);
        put(pfx + QStringLiteral("openBetTightMul"), bp.open_bet_tight_mul);
        put(pfx + QStringLiteral("bbCheckraiseBonus"), bp.bb_checkraise_bonus);
        put(pfx + QStringLiteral("bbCheckraiseTightMul"), bp.bb_checkraise_tight_mul);
    }

    if (onlyIfMissingKeys)
    {
        if (AppStateSqlite::contains(QStringLiteral("v1/bankrollHistory"))
            && AppStateSqlite::contains(QStringLiteral("v1/bankrollSnapshotTimesMs"))
            && AppStateSqlite::contains(QStringLiteral("v1/sessionBaseline")))
        {
            AppStateSqlite::commitTransaction();
            AppStateSqlite::sync();
            return;
        }
    }
    save_bankroll_session_to_settings();
    AppStateSqlite::commitTransaction();
    AppStateSqlite::sync();
}
