// Pushes `game` state to the table QML root (`m_root`): stacks, cards, timers, HUD chips.

#include "game.hpp"

#include "cards.hpp"
#include "holdem_side_pot.hpp"
#include "human_decision_controller.hpp"

#include <QCoreApplication>
#include <QEventLoop>
#include <QString>
#include <QVariant>
#include <vector>

void game::sync_ui()
{
    if (!m_root)
        return;

    m_root->setProperty("showdown", ui_showdown_);
    m_root->setProperty("handSeq", hand_seq_);
    m_root->setProperty("pot", pot);
    {
        QVariantList potSliceList;
        if (pot > 0)
        {
            const int n = players_count();
            std::vector<int> contrib(static_cast<size_t>(n));
            for (int i = 0; i < n; ++i)
                contrib[static_cast<size_t>(i)] = hand_contrib_[static_cast<size_t>(i)];
            std::vector<NlheSidePotSlice> slices;
            if (nlhe_build_side_pot_slices(contrib, pot, &slices))
            {
                for (const NlheSidePotSlice &sl : slices)
                    potSliceList.append(sl.amount);
            }
            else
                potSliceList.append(pot);
        }
        m_root->setProperty("potSlices", potSliceList);
    }
    m_root->setProperty("buttonSeat", button);
    m_root->setProperty("sbSeat", sb_seat_);
    m_root->setProperty("bbSeat", bb_seat_);
    m_root->setProperty("playerCount", players_count());
    m_root->setProperty("actingSeat", acting_seat_);
    m_root->setProperty("decisionSecondsLeft", human_decision_ctrl_->decisionSecondsLeft());
    m_root->setProperty("humanMoreTimeAvailable",
                         (human_decision_ctrl_->isWaitingForHuman() || 
                          human_decision_ctrl_->isWaitingForHumanCheck() ||
                          human_decision_ctrl_->isWaitingForHumanBbPreflop()) &&
                          human_decision_ctrl_->humanMoreTimeAvailable());
    m_root->setProperty("humanCanCheck", human_decision_ctrl_->isWaitingForHumanCheck());
    m_root->setProperty("humanBbPreflopOption", human_decision_ctrl_->isWaitingForHumanBbPreflop());
    {
        bool can_raise_facing = false;
        if (human_decision_ctrl_->isWaitingForHuman())
        {
            const int si = kHumanSeat;
            const int need = human_decision_ctrl_->pendingHumanNeed();
            const int inc = human_decision_ctrl_->pendingHumanRaiseInc();
            can_raise_facing = (inc > 0) && (table[static_cast<size_t>(si)].stack >= need + inc);
        }
        m_root->setProperty("humanCanRaiseFacing", can_raise_facing);
    }
    if (human_decision_ctrl_->isWaitingForHuman())
    {
        const int si = kHumanSeat;
        m_root->setProperty("facingNeedChips", human_decision_ctrl_->pendingHumanNeed());
        m_root->setProperty("facingMinRaiseChips", human_decision_ctrl_->pendingHumanNeed() + human_decision_ctrl_->pendingHumanRaiseInc());
        m_root->setProperty("facingMaxChips", table[static_cast<size_t>(si)].stack);
        m_root->setProperty("facingPotAmount", pot);
    }
    else
    {
        m_root->setProperty("facingNeedChips", 0);
        m_root->setProperty("facingMinRaiseChips", 0);
        m_root->setProperty("facingMaxChips", 0);
        m_root->setProperty("facingPotAmount", pot);
    }
    if (human_decision_ctrl_->isWaitingForHumanCheck())
    {
        const int stack = table[static_cast<size_t>(kHumanSeat)].stack;
        const int sb = street_bet_;
        const int minOpen = (stack >= sb) ? sb : std::max(1, stack);
        m_root->setProperty("openRaiseMinChips", minOpen);
        m_root->setProperty("openRaiseMaxChips", stack);
    }
    else
    {
        m_root->setProperty("openRaiseMinChips", 0);
        m_root->setProperty("openRaiseMaxChips", 0);
    }
    if (human_decision_ctrl_->isWaitingForHumanBbPreflop())
    {
        const int inc = min_raise_increment_chips(big_blind, last_raise_increment_);
        m_root->setProperty("bbPreflopMinChips", std::max(1, inc));
        m_root->setProperty("bbPreflopMaxChips", table[static_cast<size_t>(kHumanSeat)].stack);
    }
    else
    {
        m_root->setProperty("bbPreflopMinChips", 0);
        m_root->setProperty("bbPreflopMaxChips", 0);
    }
    m_root->setProperty("smallBlind", small_blind);
    m_root->setProperty("bigBlind", big_blind);
    m_root->setProperty("humanSittingOut", human_sitting_out_);

    {
        QVariantList part;
        for (int i = 0; i < kMaxPlayers; ++i)
            part.append(this->seatParticipating(i));
        m_root->setProperty("seatParticipating", part);
    }

    {
        const size_t hi = static_cast<size_t>(kHumanSeat);
        m_root->setProperty("humanStackChips", table[hi].stack);
        bool bb_can_raise = false;
        if (human_decision_ctrl_->isWaitingForHumanBbPreflop())
        {
            const int inc = min_raise_increment_chips(big_blind, last_raise_increment_);
            bb_can_raise = (inc > 0 && table[hi].stack >= inc && max_street_contrib() == preflop_blind_level_);
        }
        m_root->setProperty("humanBbCanRaise", bb_can_raise);
    }

    m_root->setProperty("humanHandText", human_hand_line_for_ui());

    {
        QString phase;
        if (ui_showdown_)
            phase = QStringLiteral("Showdown");
        else
        {
            switch (street)
            {
            case Street::PRE_FLOP:
                phase = QStringLiteral("Preflop");
                break;
            case Street::FLOP:
                phase = QStringLiteral("Flop");
                break;
            case Street::TURN:
                phase = QStringLiteral("Turn");
                break;
            case Street::RIVER:
                phase = QStringLiteral("River");
                break;
            }
        }
        m_root->setProperty("streetPhase", phase);
    }

    QVariantList stacks;
    QVariantList c1;
    QVariantList c2;
    QVariantList inHand;
    for (int i = 0; i < kMaxPlayers; ++i)
    {
        if (i < players_count())
        {
            stacks.append(table[static_cast<size_t>(i)].stack);
            c1.append(cards_dealt_ ? card_to_qml_asset_path(table[static_cast<size_t>(i)].first_card) : QString());
            c2.append(cards_dealt_ ? card_to_qml_asset_path(table[static_cast<size_t>(i)].second_card) : QString());
            inHand.append(in_hand_[static_cast<size_t>(i)]);
        }
        else
        {
            stacks.append(0);
            c1.append(QString());
            c2.append(QString());
            inHand.append(false);
        }
    }
    m_root->setProperty("seatStacks", stacks);
    m_root->setProperty("seatC1", c1);
    m_root->setProperty("seatC2", c2);
    m_root->setProperty("seatInHand", inHand);

    QVariantList streetBet;
    for (int i = 0; i < kMaxPlayers; ++i)
    {
        if (i < players_count())
            streetBet.append(street_contrib_[static_cast<size_t>(i)]);
        else
            streetBet.append(0);
    }
    m_root->setProperty("seatStreetChips", streetBet);

    m_root->setProperty("maxStreetContrib", max_street_contrib());

    {
        QVariantList actionLabels;
        for (int i = 0; i < kMaxPlayers; ++i)
        {
            if (i < players_count())
                actionLabels.append(seat_street_action_label_[static_cast<size_t>(i)]);
            else
                actionLabels.append(QString());
        }
        m_root->setProperty("seatStreetActions", actionLabels);
    }

    m_root->setProperty("humanCanBuyBackIn", canBuyBackIn(kHumanSeat));
    m_root->setProperty("buyInChips", effectiveSeatBuyInChips(kHumanSeat));

    m_root->setProperty("board0", (street >= Street::FLOP && flop.size() > 0) ? card_to_qml_asset_path(flop[0]) : QString());
    m_root->setProperty("board1", (street >= Street::FLOP && flop.size() > 1) ? card_to_qml_asset_path(flop[1]) : QString());
    m_root->setProperty("board2", (street >= Street::FLOP && flop.size() > 2) ? card_to_qml_asset_path(flop[2]) : QString());
    m_root->setProperty("board3", (street >= Street::TURN && flop.size() >= 3) ? card_to_qml_asset_path(turn) : QString());
    m_root->setProperty("board4", (street >= Street::RIVER && flop.size() >= 3) ? card_to_qml_asset_path(river) : QString());
}

void game::flush_ui()
{
    sync_ui();
    QCoreApplication::processEvents(QEventLoop::AllEvents, 100);
}

void game::on_pot_changed()
{
    /// Full sync: stack / buy-back eligibility must update whenever chips move (pot_changed alone left QML stale).
    sync_ui();
}
