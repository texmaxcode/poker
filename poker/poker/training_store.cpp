#include "training_store.hpp"

#include "persist_sqlite.hpp"

#include <QJsonDocument>
#include <QJsonObject>
#include <QtGlobal>

namespace {

constexpr int kDefaultTrainerAdvanceMs = 5000;
constexpr int kMinTrainerAdvanceMs = 500;
constexpr int kMaxTrainerAdvanceMs = 120000;

constexpr int kDefaultTrainerDecisionSec = 20;
constexpr int kMinTrainerDecisionSec = 5;
constexpr int kMaxTrainerDecisionSec = 120;

QString strOf(const QVariantMap &m, const QString &k)
{
    const auto v = m.value(k);
    return v.isNull() ? QString() : v.toString();
}

double dblOf(const QVariantMap &m, const QString &k)
{
    const auto v = m.value(k);
    return v.isNull() ? 0.0 : v.toDouble();
}

bool boolOf(const QVariantMap &m, const QString &k)
{
    const auto v = m.value(k);
    return v.isNull() ? false : v.toBool();
}

QJsonObject ensure_bucket(QJsonObject root, const QString &group, const QString &key)
{
    QJsonObject g = root.value(group).toObject();
    QJsonObject b = g.value(key).toObject();
    if (!b.contains("d"))
        b.insert("d", 0);
    if (!b.contains("c"))
        b.insert("c", 0);
    if (!b.contains("evBb"))
        b.insert("evBb", 0.0);
    g.insert(key, b);
    root.insert(group, g);
    return root;
}

QJsonObject bump_bucket(QJsonObject root, const QString &group, const QString &key, bool correct, double evLossBb)
{
    root = ensure_bucket(std::move(root), group, key);
    QJsonObject g = root.value(group).toObject();
    QJsonObject b = g.value(key).toObject();
    b.insert("d", b.value("d").toInt() + 1);
    if (correct)
        b.insert("c", b.value("c").toInt() + 1);
    b.insert("evBb", b.value("evBb").toDouble() + evLossBb);
    g.insert(key, b);
    root.insert(group, g);
    return root;
}

QJsonObject parse_rollup(const QString &json)
{
    if (json.trimmed().isEmpty())
        return {};
    const QJsonDocument d = QJsonDocument::fromJson(json.toUtf8());
    if (!d.isObject())
        return {};
    return d.object();
}

QString stringify(const QJsonObject &o)
{
    return QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact));
}

} // namespace

TrainingStore::TrainingStore(QObject *parent) : QObject(parent)
{
    if (!AppStateSqlite::isOpen())
        return;
    bool wrote = false;
    if (!AppStateSqlite::contains(QStringLiteral("v1/training/trainerAutoAdvanceMs")))
    {
        AppStateSqlite::setValue(QStringLiteral("v1/training/trainerAutoAdvanceMs"), kDefaultTrainerAdvanceMs);
        wrote = true;
    }
    if (!AppStateSqlite::contains(QStringLiteral("v1/training/trainerDecisionSeconds")))
    {
        AppStateSqlite::setValue(QStringLiteral("v1/training/trainerDecisionSeconds"), kDefaultTrainerDecisionSec);
        wrote = true;
    }
    if (wrote)
        AppStateSqlite::sync();
}

int TrainingStore::trainerAutoAdvanceMs() const
{
    if (!AppStateSqlite::isOpen())
        return kDefaultTrainerAdvanceMs;
    const int v = AppStateSqlite::value(QStringLiteral("v1/training/trainerAutoAdvanceMs"), kDefaultTrainerAdvanceMs).toInt();
    return qBound(kMinTrainerAdvanceMs, v, kMaxTrainerAdvanceMs);
}

void TrainingStore::setTrainerAutoAdvanceMs(int ms)
{
    if (!AppStateSqlite::isOpen())
        return;
    const int w = qBound(kMinTrainerAdvanceMs, ms, kMaxTrainerAdvanceMs);
    const int cur = qBound(
        kMinTrainerAdvanceMs,
        AppStateSqlite::value(QStringLiteral("v1/training/trainerAutoAdvanceMs"), kDefaultTrainerAdvanceMs).toInt(),
        kMaxTrainerAdvanceMs);
    if (w == cur)
        return;
    AppStateSqlite::setValue(QStringLiteral("v1/training/trainerAutoAdvanceMs"), w);
    AppStateSqlite::sync();
    emit trainerAutoAdvanceMsChanged();
}

int TrainingStore::trainerDecisionSeconds() const
{
    if (!AppStateSqlite::isOpen())
        return kDefaultTrainerDecisionSec;
    const int v =
        AppStateSqlite::value(QStringLiteral("v1/training/trainerDecisionSeconds"), kDefaultTrainerDecisionSec).toInt();
    return qBound(kMinTrainerDecisionSec, v, kMaxTrainerDecisionSec);
}

void TrainingStore::setTrainerDecisionSeconds(int sec)
{
    if (!AppStateSqlite::isOpen())
        return;
    const int w = qBound(kMinTrainerDecisionSec, sec, kMaxTrainerDecisionSec);
    const int cur = qBound(
        kMinTrainerDecisionSec,
        AppStateSqlite::value(QStringLiteral("v1/training/trainerDecisionSeconds"), kDefaultTrainerDecisionSec).toInt(),
        kMaxTrainerDecisionSec);
    if (w == cur)
        return;
    AppStateSqlite::setValue(QStringLiteral("v1/training/trainerDecisionSeconds"), w);
    AppStateSqlite::sync();
    emit trainerDecisionSecondsChanged();
}

QVariantMap TrainingStore::loadProgress() const
{
    QVariantMap out;
    if (!AppStateSqlite::isOpen())
    {
        out.insert(QStringLiteral("schemaVersion"), kSchemaVersion);
        out.insert(QStringLiteral("totalDecisions"), static_cast<qlonglong>(0));
        out.insert(QStringLiteral("totalCorrect"), static_cast<qlonglong>(0));
        out.insert(QStringLiteral("totalEvLossBb"), 0.0);
        out.insert(QStringLiteral("rollupJson"), QString());
        return out;
    }
    out.insert(QStringLiteral("schemaVersion"),
               AppStateSqlite::value(QStringLiteral("v1/training/schemaVersion"), kSchemaVersion).toInt());
    out.insert(QStringLiteral("totalDecisions"),
               AppStateSqlite::value(QStringLiteral("v1/training/totalDecisions"), static_cast<qlonglong>(0)).toLongLong());
    out.insert(QStringLiteral("totalCorrect"),
               AppStateSqlite::value(QStringLiteral("v1/training/totalCorrect"), static_cast<qlonglong>(0)).toLongLong());
    out.insert(QStringLiteral("totalEvLossBb"),
               AppStateSqlite::value(QStringLiteral("v1/training/totalEvLossBb"), 0.0).toDouble());
    out.insert(QStringLiteral("rollupJson"),
               AppStateSqlite::value(QStringLiteral("v1/training/rollupJson"), QString()).toString());
    return out;
}

void TrainingStore::recordDecision(const QVariantMap &event)
{
    if (!AppStateSqlite::isOpen())
        return;
    const QString position = strOf(event, QStringLiteral("position")).trimmed();
    const QString street = strOf(event, QStringLiteral("street")).trimmed();
    const QString spotId = strOf(event, QStringLiteral("spotId")).trimmed();
    const bool correct = boolOf(event, QStringLiteral("correct"));
    const double evLossBb = std::max(0.0, dblOf(event, QStringLiteral("evLossBb")));

    AppStateSqlite::setValue(QStringLiteral("v1/training/schemaVersion"), kSchemaVersion);

    const qlonglong totalD =
        AppStateSqlite::value(QStringLiteral("v1/training/totalDecisions"), static_cast<qlonglong>(0)).toLongLong() + 1;
    const qlonglong totalC =
        AppStateSqlite::value(QStringLiteral("v1/training/totalCorrect"), static_cast<qlonglong>(0)).toLongLong()
        + (correct ? 1 : 0);
    const double totalEv =
        AppStateSqlite::value(QStringLiteral("v1/training/totalEvLossBb"), 0.0).toDouble() + evLossBb;
    AppStateSqlite::setValue(QStringLiteral("v1/training/totalDecisions"), totalD);
    AppStateSqlite::setValue(QStringLiteral("v1/training/totalCorrect"), totalC);
    AppStateSqlite::setValue(QStringLiteral("v1/training/totalEvLossBb"), totalEv);

    QJsonObject roll =
        parse_rollup(AppStateSqlite::value(QStringLiteral("v1/training/rollupJson"), QString()).toString());
    if (!position.isEmpty())
        roll = bump_bucket(std::move(roll), QStringLiteral("position"), position, correct, evLossBb);
    if (!street.isEmpty())
        roll = bump_bucket(std::move(roll), QStringLiteral("street"), street, correct, evLossBb);
    if (!spotId.isEmpty())
        roll = bump_bucket(std::move(roll), QStringLiteral("spots"), spotId, correct, evLossBb);
    AppStateSqlite::setValue(QStringLiteral("v1/training/rollupJson"), stringify(roll));

    AppStateSqlite::sync();
    emit progressChanged();
}

void TrainingStore::resetProgress()
{
    if (!AppStateSqlite::isOpen())
        return;
    const int adv = qBound(
        kMinTrainerAdvanceMs,
        AppStateSqlite::value(QStringLiteral("v1/training/trainerAutoAdvanceMs"), kDefaultTrainerAdvanceMs).toInt(),
        kMaxTrainerAdvanceMs);
    const int dec = qBound(
        kMinTrainerDecisionSec,
        AppStateSqlite::value(QStringLiteral("v1/training/trainerDecisionSeconds"), kDefaultTrainerDecisionSec).toInt(),
        kMaxTrainerDecisionSec);
    AppStateSqlite::removeKeysWithPrefix(QStringLiteral("v1/training/"));
    AppStateSqlite::setValue(QStringLiteral("v1/training/trainerAutoAdvanceMs"), adv);
    AppStateSqlite::setValue(QStringLiteral("v1/training/trainerDecisionSeconds"), dec);
    AppStateSqlite::sync();
    emit progressChanged();
}
