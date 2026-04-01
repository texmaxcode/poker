#include "session_store.hpp"

#include <QSettings>

namespace {

QString strOf(const QVariantMap &m, const QString &key, const QString &def)
{
    return m.value(key, def).toString();
}

int intOf(const QVariantMap &m, const QString &key, int def)
{
    return m.value(key, def).toInt();
}

} // namespace

SessionStore::SessionStore(QObject *parent)
    : QObject(parent)
{
}

QVariantMap SessionStore::loadSolverFields() const
{
    QSettings s;
    QVariantMap m;
    s.beginGroup(QStringLiteral("v1"));
    s.beginGroup(QStringLiteral("solver"));
    m[QStringLiteral("hero1")] = s.value(QStringLiteral("hero1"), QStringLiteral("Ah")).toString();
    m[QStringLiteral("hero2")] = s.value(QStringLiteral("hero2"), QStringLiteral("Kd")).toString();
    m[QStringLiteral("board")] = s.value(QStringLiteral("board")).toString();
    m[QStringLiteral("villainRange")] =
        s.value(QStringLiteral("villainRange"), QStringLiteral("AA,TT+,AKs,AKo")).toString();
    m[QStringLiteral("villainE1")] = s.value(QStringLiteral("villainE1"), QStringLiteral("Qs")).toString();
    m[QStringLiteral("villainE2")] = s.value(QStringLiteral("villainE2"), QStringLiteral("Jh")).toString();
    m[QStringLiteral("iterations")] = s.value(QStringLiteral("iterations"), 40000).toInt();
    m[QStringLiteral("potBeforeCall")] = s.value(QStringLiteral("potBeforeCall"), 100).toInt();
    m[QStringLiteral("toCall")] = s.value(QStringLiteral("toCall"), 50).toInt();
    s.endGroup();
    s.endGroup();
    return m;
}

void SessionStore::saveSolverFields(const QVariantMap &m)
{
    QSettings s;
    s.beginGroup(QStringLiteral("v1"));
    s.beginGroup(QStringLiteral("solver"));
    s.setValue(QStringLiteral("hero1"), strOf(m, QStringLiteral("hero1"), QStringLiteral("Ah")));
    s.setValue(QStringLiteral("hero2"), strOf(m, QStringLiteral("hero2"), QStringLiteral("Kd")));
    s.setValue(QStringLiteral("board"), strOf(m, QStringLiteral("board"), QString()));
    s.setValue(QStringLiteral("villainRange"),
               strOf(m, QStringLiteral("villainRange"), QStringLiteral("AA,TT+,AKs,AKo")));
    s.setValue(QStringLiteral("villainE1"), strOf(m, QStringLiteral("villainE1"), QStringLiteral("Qs")));
    s.setValue(QStringLiteral("villainE2"), strOf(m, QStringLiteral("villainE2"), QStringLiteral("Jh")));
    s.setValue(QStringLiteral("iterations"), intOf(m, QStringLiteral("iterations"), 40000));
    s.setValue(QStringLiteral("potBeforeCall"), intOf(m, QStringLiteral("potBeforeCall"), 100));
    s.setValue(QStringLiteral("toCall"), intOf(m, QStringLiteral("toCall"), 50));
    s.endGroup();
    s.endGroup();
    s.sync();
}
