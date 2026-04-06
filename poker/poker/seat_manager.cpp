#include "seat_manager.hpp"

#include "game.hpp"

#include <algorithm>
#include <cassert>

static_assert(SeatManager::kMaxPlayers == game::kMaxPlayers,
              "SeatManager and game must agree on kMaxPlayers");

SeatManager::SeatManager(game &g)
    : game_(g)
{
    seat_participating_.fill(true);
    /// Buy-in targets only; chips come from `configure` / apply / persistence (clean install: $0 on table & wallet).
    seat_buy_in_.fill(0);
    seat_wallet_.fill(0);
    pending_bankroll_total_.fill(-1);
}

int SeatManager::maxBuyInChips() const
{
    return std::max(1, game_.configuredMaxOnTableBb()) * std::max(1, game_.big_blind);
}

int SeatManager::seatBuyIn(int seat) const
{
    if (seat < 0 || seat >= kMaxPlayers)
        return game_.starting_stack_;
    return seat_buy_in_[static_cast<size_t>(seat)];
}

void SeatManager::setSeatBuyIn(int seat, int chips)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return;
    const int cap = maxBuyInChips();
    int capped = std::min(chips, cap);
    capped = std::min(capped, 2000000000);
    seat_buy_in_[static_cast<size_t>(seat)] = std::max(0, capped);
    if (game_.in_progress)
        pending_seat_buyins_apply_ = true;
    game_.notifySessionStatsChanged();
}

void SeatManager::applySeatBuyInsToStacks()
{
    if (game_.in_progress)
        return;
    apply_seat_buy_ins_to_table();
    pending_seat_buyins_apply_ = false;
    game_.flush_ui();
}

bool SeatManager::pendingSeatBankrollApply() const
{
    for (int i = 0; i < kMaxPlayers; ++i)
    {
        if (pending_bankroll_total_[static_cast<size_t>(i)] >= 0)
            return true;
    }
    return false;
}

int SeatManager::seatBankrollTotal(int seat) const
{
    if (seat < 0 || seat >= kMaxPlayers)
        return 0;
    const size_t si = static_cast<size_t>(seat);
    if (pending_bankroll_total_[si] >= 0)
        return pending_bankroll_total_[si];
    return game_.table[si].stack + seat_wallet_[si];
}

void SeatManager::setSeatBankrollTotal(int seat, int totalChips)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return;
    const int t = std::clamp(totalChips, 0, 2000000000);
    if (game_.in_progress)
    {
        pending_bankroll_total_[static_cast<size_t>(seat)] = t;
        game_.notifySessionStatsChanged();
        return;
    }
    apply_seat_bankroll_total_now(seat, t);
    pending_bankroll_total_[static_cast<size_t>(seat)] = -1;
}

void SeatManager::applyPendingBankrollTotals()
{
    flush_pending_bankroll_totals();
}

int SeatManager::seatWallet(int seat) const
{
    if (seat < 0 || seat >= kMaxPlayers)
        return 0;
    return seat_wallet_[static_cast<size_t>(seat)];
}

bool SeatManager::canBuyBackIn(int seat) const
{
    if (seat < 0 || seat >= game_.players_count())
        return false;
    const size_t si = static_cast<size_t>(seat);
    if (game_.in_progress && game_.in_hand_[si])
        return false;
    if (game_.table[si].stack > 0)
        return false;
    const int cost = game_.effectiveSeatBuyInChips(seat);
    return seat_wallet_[si] >= cost;
}

bool SeatManager::tryBuyBackIn(int seat)
{
    if (!apply_buy_back_in_internal(seat))
        return false;
    game_.bankroll_tracker_.record_bankroll_snapshot();
    game_.savePersistedSettings();
    game_.flush_ui();
    return true;
}

void SeatManager::setSeatParticipating(int seat, bool participating)
{
    if (seat < 1 || seat >= kMaxPlayers)
        return;
    seat_participating_[static_cast<size_t>(seat)] = participating;
}

bool SeatManager::seatParticipating(int seat) const
{
    if (seat < 0 || seat >= kMaxPlayers)
        return true;
    return seat_participating_[static_cast<size_t>(seat)];
}

void SeatManager::apply_seat_buy_ins_to_table(bool resetBankrollSession)
{
    const int cap = maxBuyInChips();
    long long total_chips_in_play = 0;
    for (size_t i = 0; i < game_.table.size(); ++i)
        total_chips_in_play += static_cast<long long>(game_.table[i].stack) + seat_wallet_[i];
    /// Only mint play-money buy-ins when no chips exist anywhere (fresh session / empty DB). Otherwise a
    /// busted stack would get a free full rebuy every deal.
    const bool allow_empty_bankroll_bootstrap = (total_chips_in_play < 1);
    for (size_t i = 0; i < game_.table.size(); ++i)
    {
        const int seat = static_cast<int>(i);
        const int bi = game_.effectiveSeatBuyInChips(seat);
        seat_buy_in_[i] = std::clamp(bi, 0, cap);
        /// Seats 1–5 toggled off in Setup stay off the felt; wealth remains in `seat_wallet_` only.
        if (seat >= 1 && seat < kMaxPlayers && !seat_participating_[i])
        {
            const int total_wealth = game_.table[i].stack + seat_wallet_[i];
            seat_wallet_[i] = total_wealth;
            game_.table[i].reset_stack(0);
            continue;
        }
        /// With wallet + stack both at 0, there is nothing to move to the felt. Credit the buy-in target
        /// once so a fresh session (or cleared DB) can still seat players; off-table wallet stays 0 after.
        int total_wealth = game_.table[i].stack + seat_wallet_[i];
        const int target = seat_buy_in_[i];
        if (allow_empty_bankroll_bootstrap && total_wealth < 1 && target > 0
            && !(seat == 0 && game_.human_sitting_out_))
            seat_wallet_[i] += target;
        total_wealth = game_.table[i].stack + seat_wallet_[i];
        int on_table = std::min(target, cap);
        if (on_table > total_wealth)
            on_table = total_wealth;
        seat_wallet_[i] = total_wealth - on_table;
        game_.table[i].reset_stack(on_table);
    }
    if (resetBankrollSession)
        game_.bankroll_tracker_.init_bankroll_after_configure();
}

void SeatManager::try_auto_rebuys_for_busted_bots()
{
    const int n = game_.players_count();
    for (int s = 0; s < n; ++s)
    {
        /// Seat 0: auto-rebuy only when autoplaying as a bot; the human uses the HUD buy-back button.
        if (s == 0 && game_.interactiveHuman())
            continue;
        if (!seat_participating_[static_cast<size_t>(s)])
            continue;
        const size_t si = static_cast<size_t>(s);
        if (game_.table[si].stack > 0)
            continue;
        /// Never inflate `seat_wallet_` — rebuy only from chips already in Settings / DB (stack + wallet).
        apply_buy_back_in_internal(s);
    }
}

void SeatManager::cash_out_seat_off_table(int seat)
{
    if (seat < 1 || seat >= kMaxPlayers)
        return;
    const size_t si = static_cast<size_t>(seat);
    const int st = game_.table[si].stack;
    if (st <= 0)
        return;
    seat_wallet_[si] += st;
    game_.table[si].reset_stack(0);
}

void SeatManager::mark_pending_cash_out_after_hand(int seat)
{
    if (seat >= 1 && seat < kMaxPlayers)
        pending_cash_out_after_hand_[static_cast<size_t>(seat)] = true;
}

void SeatManager::flush_pending_cash_outs_after_hand()
{
    for (int s = 1; s < kMaxPlayers; ++s)
    {
        const size_t si = static_cast<size_t>(s);
        if (!pending_cash_out_after_hand_[si])
            continue;
        pending_cash_out_after_hand_[si] = false;
        cash_out_seat_off_table(s);
    }
}

bool SeatManager::apply_buy_back_in_internal(int seat)
{
    if (seat < 0 || seat >= game_.players_count())
        return false;
    const size_t si = static_cast<size_t>(seat);
    if (game_.in_progress && game_.in_hand_[si])
        return false;
    if (game_.table[si].stack > 0)
        return false;
    const int cost = game_.effectiveSeatBuyInChips(seat);
    if (cost < 1 || seat_wallet_[si] < 1)
        return false;
    /// Move up to full buy-in; partial stack when wallet is short (matches `apply_seat_buy_ins_to_table`).
    const int move = std::min(cost, seat_wallet_[si]);
    game_.table[si].stack += move;
    seat_wallet_[si] -= move;
    return true;
}

void SeatManager::sync_seat_buy_in_from_table_when_wallet_empty()
{
    if (game_.in_progress)
        return;
    const int n = game_.players_count();
    const int cap = maxBuyInChips();
    for (int i = 0; i < n; ++i)
    {
        const size_t si = static_cast<size_t>(i);
        const int st = game_.table[si].stack;
        const int w = seat_wallet_[si];
        const int total = st + w;
        if (total < 1)
            continue;
        /// Busted (no on-table chips): keep `seat_buy_in_` as the rebuy target and `wallet` as stored.
        if (st < 1)
            continue;
        /// When `wallet > 0`, the old logic only updated `seat_buy_in_` if wallet was empty, so winnings
        /// that increased `stack` were never written to `v1/seat*/buyIn` — reload then dropped chips.
        /// Normalize buy-in + wallet from actual stack + wallet (same total); cap excess stack into wallet.
        const int on_table = std::min(st, cap);
        seat_buy_in_[si] = std::max(1, on_table);
        seat_wallet_[si] = total - seat_buy_in_[si];
        game_.table[si].reset_stack(seat_buy_in_[si]);
    }
}

void SeatManager::flush_pending_bankroll_totals()
{
    if (game_.in_progress)
        return;
    for (int i = 0; i < kMaxPlayers; ++i)
    {
        const int pending = pending_bankroll_total_[static_cast<size_t>(i)];
        if (pending >= 0)
        {
            apply_seat_bankroll_total_now(i, pending);
            pending_bankroll_total_[static_cast<size_t>(i)] = -1;
        }
    }
}

void SeatManager::apply_seat_bankroll_total_now(int seat, int totalChips)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return;
    const int t = std::clamp(totalChips, 0, 2000000000);
    const size_t si = static_cast<size_t>(seat);
    const int cap = maxBuyInChips();
    const int on_table = std::min(t, cap);
    seat_buy_in_[si] = on_table;
    game_.table[si].reset_stack(on_table);
    seat_wallet_[si] = t - on_table;
    game_.bankroll_tracker_.record_bankroll_snapshot();
    game_.savePersistedSettings();
    game_.flush_ui();
}
