#ifndef SEAT_MANAGER_HPP
#define SEAT_MANAGER_HPP

#include <array>

class game;
class GamePersistence;
class BankrollTracker;

/// Manages per-seat buy-ins, wallets, participation flags, and bankroll totals.
/// Plain C++ class (not QObject); owned by `game` which delegates Q_INVOKABLE calls here.
class SeatManager
{
    friend class game;
    friend class GamePersistence;
    friend class BankrollTracker;

public:
    static constexpr int kMaxPlayers = 6;

    explicit SeatManager(game &g);

    int maxBuyInChips() const;

    int seatBuyIn(int seat) const;
    void setSeatBuyIn(int seat, int chips);
    void applySeatBuyInsToStacks();
    bool pendingSeatBuyInsApply() const { return pending_seat_buyins_apply_; }

    int seatBankrollTotal(int seat) const;
    void setSeatBankrollTotal(int seat, int totalChips);
    bool pendingSeatBankrollApply() const;
    void applyPendingBankrollTotals();

    int seatWallet(int seat) const;
    bool canBuyBackIn(int seat) const;
    bool tryBuyBackIn(int seat);

    void setSeatParticipating(int seat, bool participating);
    bool seatParticipating(int seat) const;

    void apply_seat_buy_ins_to_table(bool resetBankrollSession = true);
    void try_auto_rebuys_for_busted_bots();
    bool apply_buy_back_in_internal(int seat);
    /// Move all on-table chips to `seat_wallet_` (seat 1–5: bot toggled off in Setup).
    void cash_out_seat_off_table(int seat);
    /// Top up wallet if needed, then put `effectiveSeatBuyInChips` on the felt when stack is 0 (bot toggled on).
    void apply_bot_seat_rejoin_buy_in(int seat);
    void mark_pending_cash_out_after_hand(int seat);
    void flush_pending_cash_outs_after_hand();
    /// Rewrites `seat_buy_in_` / `seat_wallet_` from current stacks (and caps stack to `maxBuyInChips`)
    /// so `savePersistedSettings` preserves winnings even when off-table wallet was non-zero.
    void sync_seat_buy_in_from_table_when_wallet_empty();
    void flush_pending_bankroll_totals();
    void apply_seat_bankroll_total_now(int seat, int totalChips);

private:
    game &game_;

    std::array<int, kMaxPlayers> seat_buy_in_{};
    std::array<int, kMaxPlayers> seat_wallet_{};
    std::array<bool, kMaxPlayers> seat_participating_{};
    /// Bot seat turned off mid-hand: cash out stack at end of hand (before next deal).
    std::array<bool, kMaxPlayers> pending_cash_out_after_hand_{};
    /// `-1` = none; else total chips to apply for that seat (`setSeatBankrollTotal` while `in_progress`).
    std::array<int, kMaxPlayers> pending_bankroll_total_{};
    bool pending_seat_buyins_apply_ = false;
};

#endif // SEAT_MANAGER_HPP
