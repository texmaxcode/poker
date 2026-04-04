#include "session_store.hpp"

#include "persist_sqlite.hpp"

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
    QVariantMap m;
    const QString p = QStringLiteral("v1/solver/");
    m[QStringLiteral("hero1")] =
        AppStateSqlite::value(p + QStringLiteral("hero1"), QStringLiteral("Ah")).toString();
    m[QStringLiteral("hero2")] =
        AppStateSqlite::value(p + QStringLiteral("hero2"), QStringLiteral("Kd")).toString();
    m[QStringLiteral("board")] = AppStateSqlite::value(p + QStringLiteral("board"), QString()).toString();
    m[QStringLiteral("villainRange")] =
        AppStateSqlite::value(p + QStringLiteral("villainRange"), QStringLiteral("AA,TT+,AKs,AKo")).toString();
    m[QStringLiteral("villainE1")] =
        AppStateSqlite::value(p + QStringLiteral("villainE1"), QStringLiteral("Qs")).toString();
    m[QStringLiteral("villainE2")] =
        AppStateSqlite::value(p + QStringLiteral("villainE2"), QStringLiteral("Jh")).toString();
    m[QStringLiteral("iterations")] =
        AppStateSqlite::value(p + QStringLiteral("iterations"), 40000).toInt();
    m[QStringLiteral("potBeforeCall")] =
        AppStateSqlite::value(p + QStringLiteral("potBeforeCall"), 100).toInt();
    m[QStringLiteral("toCall")] = AppStateSqlite::value(p + QStringLiteral("toCall"), 50).toInt();
    return m;
}

void SessionStore::saveSolverFields(const QVariantMap &m)
{
    if (!AppStateSqlite::isOpen())
        return;
    const QString p = QStringLiteral("v1/solver/");
    AppStateSqlite::setValue(p + QStringLiteral("hero1"), strOf(m, QStringLiteral("hero1"), QStringLiteral("Ah")));
    AppStateSqlite::setValue(p + QStringLiteral("hero2"), strOf(m, QStringLiteral("hero2"), QStringLiteral("Kd")));
    AppStateSqlite::setValue(p + QStringLiteral("board"), strOf(m, QStringLiteral("board"), QString()));
    AppStateSqlite::setValue(p + QStringLiteral("villainRange"),
                             strOf(m, QStringLiteral("villainRange"), QStringLiteral("AA,TT+,AKs,AKo")));
    AppStateSqlite::setValue(p + QStringLiteral("villainE1"), strOf(m, QStringLiteral("villainE1"), QStringLiteral("Qs")));
    AppStateSqlite::setValue(p + QStringLiteral("villainE2"), strOf(m, QStringLiteral("villainE2"), QStringLiteral("Jh")));
    AppStateSqlite::setValue(p + QStringLiteral("iterations"), intOf(m, QStringLiteral("iterations"), 40000));
    AppStateSqlite::setValue(p + QStringLiteral("potBeforeCall"), intOf(m, QStringLiteral("potBeforeCall"), 100));
    AppStateSqlite::setValue(p + QStringLiteral("toCall"), intOf(m, QStringLiteral("toCall"), 50));
    AppStateSqlite::sync();
}
