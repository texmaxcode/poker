#include "training_store.hpp"

#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QtGlobal>

namespace {

constexpr char kV1[] = "v1";
constexpr char kTraining[] = "training";

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

TrainingStore::TrainingStore(QObject *parent) : QObject(parent) {}

int TrainingStore::trainerAutoAdvanceMs() const
{
    QSettings s;
    s.beginGroup(QString::fromLatin1(kV1));
    s.beginGroup(QString::fromLatin1(kTraining));
    const int v = s.value(QStringLiteral("trainerAutoAdvanceMs"), kDefaultTrainerAdvanceMs).toInt();
    s.endGroup();
    s.endGroup();
    return qBound(kMinTrainerAdvanceMs, v, kMaxTrainerAdvanceMs);
}

void TrainingStore::setTrainerAutoAdvanceMs(int ms)
{
    const int w = qBound(kMinTrainerAdvanceMs, ms, kMaxTrainerAdvanceMs);
    QSettings s;
    s.beginGroup(QString::fromLatin1(kV1));
    s.beginGroup(QString::fromLatin1(kTraining));
    const int cur = qBound(
        kMinTrainerAdvanceMs,
        s.value(QStringLiteral("trainerAutoAdvanceMs"), kDefaultTrainerAdvanceMs).toInt(),
        kMaxTrainerAdvanceMs);
    if (w == cur)
    {
        s.endGroup();
        s.endGroup();
        return;
    }
    s.setValue(QStringLiteral("trainerAutoAdvanceMs"), w);
    s.endGroup();
    s.endGroup();
    s.sync();
    emit trainerAutoAdvanceMsChanged();
}

int TrainingStore::trainerDecisionSeconds() const
{
    QSettings s;
    s.beginGroup(QString::fromLatin1(kV1));
    s.beginGroup(QString::fromLatin1(kTraining));
    const int v = s.value(QStringLiteral("trainerDecisionSeconds"), kDefaultTrainerDecisionSec).toInt();
    s.endGroup();
    s.endGroup();
    return qBound(kMinTrainerDecisionSec, v, kMaxTrainerDecisionSec);
}

void TrainingStore::setTrainerDecisionSeconds(int sec)
{
    const int w = qBound(kMinTrainerDecisionSec, sec, kMaxTrainerDecisionSec);
    QSettings s;
    s.beginGroup(QString::fromLatin1(kV1));
    s.beginGroup(QString::fromLatin1(kTraining));
    const int cur = qBound(
        kMinTrainerDecisionSec,
        s.value(QStringLiteral("trainerDecisionSeconds"), kDefaultTrainerDecisionSec).toInt(),
        kMaxTrainerDecisionSec);
    if (w == cur)
    {
        s.endGroup();
        s.endGroup();
        return;
    }
    s.setValue(QStringLiteral("trainerDecisionSeconds"), w);
    s.endGroup();
    s.endGroup();
    s.sync();
    emit trainerDecisionSecondsChanged();
}

QVariantMap TrainingStore::loadProgress() const
{
    QSettings s;
    s.beginGroup(QString::fromLatin1(kV1));
    s.beginGroup(QString::fromLatin1(kTraining));

    QVariantMap out;
    out.insert(QStringLiteral("schemaVersion"), s.value(QStringLiteral("schemaVersion"), kSchemaVersion).toInt());
    out.insert(QStringLiteral("totalDecisions"), s.value(QStringLiteral("totalDecisions"), 0).toLongLong());
    out.insert(QStringLiteral("totalCorrect"), s.value(QStringLiteral("totalCorrect"), 0).toLongLong());
    out.insert(QStringLiteral("totalEvLossBb"), s.value(QStringLiteral("totalEvLossBb"), 0.0).toDouble());
    out.insert(QStringLiteral("rollupJson"), s.value(QStringLiteral("rollupJson"), QString()).toString());

    s.endGroup();
    s.endGroup();
    return out;
}

void TrainingStore::recordDecision(const QVariantMap &event)
{
    const QString position = strOf(event, QStringLiteral("position")).trimmed();
    const QString street = strOf(event, QStringLiteral("street")).trimmed();
    const QString spotId = strOf(event, QStringLiteral("spotId")).trimmed();
    const bool correct = boolOf(event, QStringLiteral("correct"));
    const double evLossBb = std::max(0.0, dblOf(event, QStringLiteral("evLossBb")));

    QSettings s;
    s.beginGroup(QString::fromLatin1(kV1));
    s.beginGroup(QString::fromLatin1(kTraining));

    s.setValue(QStringLiteral("schemaVersion"), kSchemaVersion);

    const qlonglong totalD = s.value(QStringLiteral("totalDecisions"), 0).toLongLong() + 1;
    const qlonglong totalC = s.value(QStringLiteral("totalCorrect"), 0).toLongLong() + (correct ? 1 : 0);
    const double totalEv = s.value(QStringLiteral("totalEvLossBb"), 0.0).toDouble() + evLossBb;
    s.setValue(QStringLiteral("totalDecisions"), totalD);
    s.setValue(QStringLiteral("totalCorrect"), totalC);
    s.setValue(QStringLiteral("totalEvLossBb"), totalEv);

    QJsonObject roll = parse_rollup(s.value(QStringLiteral("rollupJson"), QString()).toString());
    if (!position.isEmpty())
        roll = bump_bucket(std::move(roll), QStringLiteral("position"), position, correct, evLossBb);
    if (!street.isEmpty())
        roll = bump_bucket(std::move(roll), QStringLiteral("street"), street, correct, evLossBb);
    if (!spotId.isEmpty())
        roll = bump_bucket(std::move(roll), QStringLiteral("spots"), spotId, correct, evLossBb);
    s.setValue(QStringLiteral("rollupJson"), stringify(roll));

    s.endGroup();
    s.endGroup();
    s.sync();
    emit progressChanged();
}

void TrainingStore::resetProgress()
{
    QSettings s;
    s.beginGroup(QString::fromLatin1(kV1));
    s.beginGroup(QString::fromLatin1(kTraining));
    const int adv = qBound(
        kMinTrainerAdvanceMs,
        s.value(QStringLiteral("trainerAutoAdvanceMs"), kDefaultTrainerAdvanceMs).toInt(),
        kMaxTrainerAdvanceMs);
    const int dec = qBound(
        kMinTrainerDecisionSec,
        s.value(QStringLiteral("trainerDecisionSeconds"), kDefaultTrainerDecisionSec).toInt(),
        kMaxTrainerDecisionSec);
    s.remove(QString());
    s.setValue(QStringLiteral("trainerAutoAdvanceMs"), adv);
    s.setValue(QStringLiteral("trainerDecisionSeconds"), dec);
    s.endGroup();
    s.endGroup();
    s.sync();
    emit progressChanged();
}

