#ifndef TEXAS_HOLDEM_GYM_HAND_HISTORY_QUERY_HPP
#define TEXAS_HOLDEM_GYM_HAND_HISTORY_QUERY_HPP

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QtGlobal>

/// QML-facing read API over the `hands` / `actions` tables written by `HandLogBatch`.
class HandHistoryQuery : public QObject
{
    Q_OBJECT
public:
    explicit HandHistoryQuery(QObject *parent = nullptr);

    /// Returns rows newest-first (by `started_ms`), at most `limit`, skipping `offset`.
    /// Each row is a `QVariantMap` with keys:
    ///   `id`, `startedMs`, `endedMs`, `numPlayers`,
    ///   `sbSize`, `bbSize`, `buttonSeat`, `sbSeat`, `bbSeat`,
    ///   `boardDisplay` (e.g. `"Ah Kd Qs"`), `boardAssets` (QML asset paths),
    ///   `winners` (seat indices), `actionCount`.
    Q_INVOKABLE QVariantList listRecent(int limit = 50, int offset = 0) const;

    /// Total number of rows in `hands`.
    Q_INVOKABLE int countHands() const;

    /// Full detail for a single hand (same keys as `listRecent` rows, plus `actions`: ordered array of maps with
    /// `seq`, `seat`, `street`, `kind`, `kindLabel`, `chips`, `facing`, `isBlind`).
    Q_INVOKABLE QVariantMap hand(qint64 handId) const;

    /// Drops all hand / action / player rows (used by the “Clear history” UI affordance).
    Q_INVOKABLE void clearAll();

    /// Call after another subsystem clears `hands`/`actions` (e.g. `game::factoryResetToDefaultsAndClearHistory`)
    /// so QML lists bound to this object refresh.
    Q_INVOKABLE void notifyHistoryChanged();

signals:
    /// Emitted after `clearAll()` so bound views can refresh.
    void historyChanged();
};

#endif
