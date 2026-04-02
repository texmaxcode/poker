#include "training_controller.hpp"

#include "cards.hpp"
#include "range_matrix.hpp"
#include "training_store.hpp"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include <algorithm>

namespace {

QString qrc_to_colon(QString u)
{
    if (u.startsWith(QStringLiteral("qrc:/")))
        return QStringLiteral(":/") + u.mid(5);
    return u;
}

bool parse_169(const QJsonValue &v, std::array<double, 169> &out)
{
    if (!v.isArray())
        return false;
    const QJsonArray a = v.toArray();
    if (a.size() != 169)
        return false;
    for (int i = 0; i < 169; ++i)
        out[static_cast<size_t>(i)] = a[i].toDouble();
    return true;
}

QString grade_label(double freq)
{
    if (freq >= 0.70)
        return QStringLiteral("Correct");
    if (freq >= 0.05)
        return QStringLiteral("Mix");
    return QStringLiteral("Wrong");
}

} // namespace

TrainingController::TrainingController(TrainingStore *store, QObject *parent) : QObject(parent), store_(store) {}

bool TrainingController::loadPreflopRanges(const QString &qrcUrl)
{
    scenarios_.clear();

    QFile f(qrc_to_colon(qrcUrl));
    if (!f.open(QIODevice::ReadOnly))
        return false;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject())
        return false;
    const QJsonObject root = doc.object();
    const QJsonArray arr = root.value(QStringLiteral("scenarios")).toArray();
    for (const auto &sv : arr)
    {
        if (!sv.isObject())
            continue;
        const QJsonObject o = sv.toObject();
        const QString pos = o.value(QStringLiteral("position")).toString();
        const QString mode = o.value(QStringLiteral("mode")).toString(QStringLiteral("open"));
        const QJsonObject a = o.value(QStringLiteral("actions")).toObject();
        Scenario sc;
        sc.position = pos;
        sc.mode = mode;
        if (!parse_169(a.value(QStringLiteral("fold")), sc.fold))
            continue;
        if (!parse_169(a.value(QStringLiteral("call")), sc.call))
            continue;
        if (!parse_169(a.value(QStringLiteral("raise")), sc.raise))
            continue;
        sc.loaded = true;
        scenarios_.emplace(scenario_key(pos, mode), sc);
    }
    return !scenarios_.empty();
}

bool TrainingController::loadFlopSpots(const QString &qrcUrl)
{
    flop_spots_.clear();
    flop_idx_ = -1;

    QFile f(qrc_to_colon(qrcUrl));
    if (!f.open(QIODevice::ReadOnly))
        return false;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject())
        return false;
    const QJsonObject root = doc.object();
    const QJsonArray arr = root.value(QStringLiteral("spots")).toArray();
    for (const auto &sv : arr)
    {
        if (!sv.isObject())
            continue;
        const QJsonObject o = sv.toObject();
        const QString id = o.value(QStringLiteral("id")).toString();
        const QJsonArray board = o.value(QStringLiteral("board")).toArray();
        const QJsonArray hero = o.value(QStringLiteral("heroCards")).toArray();
        if (id.isEmpty() || board.size() != 3 || hero.size() != 2)
            continue;
        const QJsonObject act = o.value(QStringLiteral("actions")).toObject();
        const QJsonObject a0 = act.value(QStringLiteral("check")).toObject();
        const QJsonObject a1 = act.value(QStringLiteral("bet33")).toObject();
        const QJsonObject a2 = act.value(QStringLiteral("bet75")).toObject();

        FlopSpot s;
        s.id = id;
        s.board0 = board[0].toString();
        s.board1 = board[1].toString();
        s.board2 = board[2].toString();
        s.hero1 = hero[0].toString();
        s.hero2 = hero[1].toString();
        s.freq_check = a0.value(QStringLiteral("freq")).toDouble();
        s.freq_b33 = a1.value(QStringLiteral("freq")).toDouble();
        s.freq_b75 = a2.value(QStringLiteral("freq")).toDouble();
        s.ev_check = a0.value(QStringLiteral("evBb")).toDouble();
        s.ev_b33 = a1.value(QStringLiteral("evBb")).toDouble();
        s.ev_b75 = a2.value(QStringLiteral("evBb")).toDouble();
        flop_spots_.push_back(s);
    }
    return !flop_spots_.empty();
}

void TrainingController::startPreflopDrill(const QString &position, const QString &mode)
{
    cur_position_ = position.trimmed().toUpper();
    cur_mode_ = mode.trimmed();
    if (cur_mode_.isEmpty())
        cur_mode_ = QStringLiteral("open");
    cur_hand_idx_ = -1;
    cur_card1_.clear();
    cur_card2_.clear();
    last_feedback_.clear();
    emit lastFeedbackChanged();
}

void TrainingController::startFlopDrill(const QString &matchup)
{
    (void)matchup;
    flop_idx_ = -1;
    last_feedback_.clear();
    emit lastFeedbackChanged();
}

QVariantMap TrainingController::nextPreflopQuestion()
{
    QVariantMap out;
    const Scenario *sc = current_scenario();
    if (!sc || !sc->loaded)
    {
        out.insert(QStringLiteral("error"), QStringLiteral("No range loaded for this position/mode."));
        return out;
    }

    // Random deal of two distinct cards.
    card_deck d;
    card a = d.get_card();
    card b = d.get_card();
    while (b == a)
        b = d.get_card();

    cur_hand_idx_ = hand_index_from_cards(a, b);
    cur_card1_ = card_to_qml_asset_path(a);
    cur_card2_ = card_to_qml_asset_path(b);

    out.insert(QStringLiteral("position"), sc->position);
    out.insert(QStringLiteral("mode"), sc->mode);
    out.insert(QStringLiteral("card1"), cur_card1_);
    out.insert(QStringLiteral("card2"), cur_card2_);
    out.insert(QStringLiteral("handIndex"), cur_hand_idx_);
    return out;
}

QVariantMap TrainingController::nextFlopQuestion()
{
    QVariantMap out;
    if (flop_spots_.empty())
    {
        out.insert(QStringLiteral("error"), QStringLiteral("No flop spots loaded."));
        return out;
    }
    flop_idx_ = (flop_idx_ + 1) % static_cast<int>(flop_spots_.size());
    const FlopSpot &s = flop_spots_[static_cast<size_t>(flop_idx_)];
    out.insert(QStringLiteral("spotId"), s.id);
    out.insert(QStringLiteral("board0"), s.board0);
    out.insert(QStringLiteral("board1"), s.board1);
    out.insert(QStringLiteral("board2"), s.board2);
    out.insert(QStringLiteral("hero1"), s.hero1);
    out.insert(QStringLiteral("hero2"), s.hero2);
    return out;
}

QVariantMap TrainingController::submitPreflopAnswer(const QString &action, int raiseSizeBb)
{
    (void)raiseSizeBb; // V1: grade action class only

    QVariantMap out;
    const Scenario *sc = current_scenario();
    if (!sc || !sc->loaded || cur_hand_idx_ < 0 || cur_hand_idx_ >= 169)
    {
        out.insert(QStringLiteral("error"), QStringLiteral("No active question."));
        return out;
    }
    const QString a = action.trimmed().toLower();
    double freq = 0.0;
    if (a == QStringLiteral("fold"))
        freq = sc->fold[static_cast<size_t>(cur_hand_idx_)];
    else if (a == QStringLiteral("call"))
        freq = sc->call[static_cast<size_t>(cur_hand_idx_)];
    else if (a == QStringLiteral("raise"))
        freq = sc->raise[static_cast<size_t>(cur_hand_idx_)];
    else
    {
        out.insert(QStringLiteral("error"), QStringLiteral("Unknown action."));
        return out;
    }

    const double best =
        std::max({sc->fold[static_cast<size_t>(cur_hand_idx_)],
                  sc->call[static_cast<size_t>(cur_hand_idx_)],
                  sc->raise[static_cast<size_t>(cur_hand_idx_)]});

    QString best_action = QStringLiteral("fold");
    if (sc->call[static_cast<size_t>(cur_hand_idx_)] >= best - 1e-12)
        best_action = QStringLiteral("call");
    if (sc->raise[static_cast<size_t>(cur_hand_idx_)] >= best - 1e-12)
        best_action = QStringLiteral("raise");

    const QString grade = grade_label(freq);
    const bool correct = (grade == QStringLiteral("Correct"));

    last_feedback_.clear();
    last_feedback_.insert(QStringLiteral("grade"), grade);
    last_feedback_.insert(QStringLiteral("chosenAction"), a);
    last_feedback_.insert(QStringLiteral("chosenFreq"), freq);
    last_feedback_.insert(QStringLiteral("bestAction"), best_action);
    last_feedback_.insert(QStringLiteral("bestFreq"), best);

    out = last_feedback_;

    if (store_)
    {
        QVariantMap ev;
        ev.insert(QStringLiteral("position"), sc->position);
        ev.insert(QStringLiteral("street"), QStringLiteral("preflop"));
        ev.insert(QStringLiteral("spotId"), QStringLiteral("preflop_%1_%2").arg(sc->position, sc->mode));
        ev.insert(QStringLiteral("correct"), correct);
        ev.insert(QStringLiteral("evLossBb"), 0.0);
        store_->recordDecision(ev);
    }

    emit lastFeedbackChanged();
    return out;
}

QVariantMap TrainingController::submitFlopAnswer(const QString &action)
{
    QVariantMap out;
    if (flop_spots_.empty() || flop_idx_ < 0 || flop_idx_ >= static_cast<int>(flop_spots_.size()))
    {
        out.insert(QStringLiteral("error"), QStringLiteral("No active flop question."));
        return out;
    }
    const FlopSpot &s = flop_spots_[static_cast<size_t>(flop_idx_)];
    const QString a = action.trimmed().toLower();

    double freq = 0.0;
    double ev = 0.0;
    if (a == QStringLiteral("check"))
    {
        freq = s.freq_check;
        ev = s.ev_check;
    }
    else if (a == QStringLiteral("bet33"))
    {
        freq = s.freq_b33;
        ev = s.ev_b33;
    }
    else if (a == QStringLiteral("bet75"))
    {
        freq = s.freq_b75;
        ev = s.ev_b75;
    }
    else
    {
        out.insert(QStringLiteral("error"), QStringLiteral("Unknown action."));
        return out;
    }

    const double best_ev = std::max({s.ev_check, s.ev_b33, s.ev_b75});
    const double ev_loss = std::max(0.0, best_ev - ev);
    const QString grade = grade_label(freq);
    const bool correct = (grade == QStringLiteral("Correct"));

    last_feedback_.clear();
    last_feedback_.insert(QStringLiteral("grade"), grade);
    last_feedback_.insert(QStringLiteral("chosenAction"), a);
    last_feedback_.insert(QStringLiteral("chosenFreq"), freq);
    last_feedback_.insert(QStringLiteral("ev"), ev);
    last_feedback_.insert(QStringLiteral("bestEv"), best_ev);
    last_feedback_.insert(QStringLiteral("evLossBb"), ev_loss);
    last_feedback_.insert(QStringLiteral("spotId"), s.id);

    out = last_feedback_;

    if (store_)
    {
        QVariantMap evm;
        evm.insert(QStringLiteral("position"), QStringLiteral("BTN"));
        evm.insert(QStringLiteral("street"), QStringLiteral("flop"));
        evm.insert(QStringLiteral("spotId"), s.id);
        evm.insert(QStringLiteral("correct"), correct);
        evm.insert(QStringLiteral("evLossBb"), ev_loss);
        store_->recordDecision(evm);
    }

    emit lastFeedbackChanged();
    return out;
}

int TrainingController::hand_index_from_cards(const card &a, const card &b)
{
    // Map to 13x13 (Ace=0..Two=12). Upper triangle suited, lower offsuit.
    const int ra = rank_index(a.rank);
    const int rb = rank_index(b.rank);
    if (ra == rb)
        return ra * 13 + rb;
    const bool suited = (a.suite == b.suite);
    const int hi = std::min(ra, rb);
    const int lo = std::max(ra, rb);
    const int row = suited ? hi : lo;
    const int col = suited ? lo : hi;
    return row * 13 + col;
}

std::string TrainingController::scenario_key(const QString &pos, const QString &mode)
{
    const QString p = pos.trimmed().toUpper();
    const QString m = mode.trimmed().isEmpty() ? QStringLiteral("open") : mode.trimmed();
    return (p + QStringLiteral("|") + m).toStdString();
}

const TrainingController::Scenario *TrainingController::current_scenario() const
{
    const auto it = scenarios_.find(scenario_key(cur_position_, cur_mode_));
    if (it == scenarios_.end())
        return nullptr;
    return &it->second;
}


