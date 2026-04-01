#ifndef TEXAS_HOLDEM_GYM_SESSION_STORE_H
#define TEXAS_HOLDEM_GYM_SESSION_STORE_H

#include <QObject>
#include <QVariantMap>

/// Persists solver / equity screen fields (same QSettings file as `game` table config).
class SessionStore : public QObject
{
    Q_OBJECT

public:
    explicit SessionStore(QObject *parent = nullptr);

    Q_INVOKABLE QVariantMap loadSolverFields() const;
    Q_INVOKABLE void saveSolverFields(const QVariantMap &m);
};

#endif // TEXAS_HOLDEM_GYM_SESSION_STORE_H
