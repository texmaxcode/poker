#include <QCoreApplication>
#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTimer>

#include "game.hpp"
#include "poker_solver.hpp"
#include "session_store.hpp"
#include "toy_nash_solver.hpp"
#include "training_store.hpp"
#include "training_controller.hpp"

int main(int argc, char *argv[])
{
    QCoreApplication::setOrganizationName(QStringLiteral("TexasHoldemGym"));
    QCoreApplication::setApplicationName(QStringLiteral("Texas Hold'em Gym"));
    QGuiApplication app(argc, argv);

    // Register bundled Oswald so QML Controls and raw Text inherit the brand typeface (see Theme.fontFamilyUi).
    QString appFontFamily = QStringLiteral("Oswald");
    {
        const int idReg = QFontDatabase::addApplicationFont(QStringLiteral(":/assets/fonts/Oswald-Regular.ttf"));
        QFontDatabase::addApplicationFont(QStringLiteral(":/assets/fonts/Oswald-Bold.ttf"));
        if (idReg != -1)
        {
            const QStringList fams = QFontDatabase::applicationFontFamilies(idReg);
            if (!fams.isEmpty())
                appFontFamily = fams.first();
        }
        QFont f = app.font();
        f.setFamily(appFontFamily);
        f.setPointSizeF(13.0);
        app.setFont(f);
    }

    game poker_game;
    poker_game.loadPersistedSettings();
    PokerSolver poker_solver;
    ToyNashSolver toy_nash_solver;
    TrainingStore training_store;
    TrainingController trainer(&training_store);
    SessionStore session_store;

    // Headless self-test for debugging crashes in toy solver code paths.
    const QStringList args = QCoreApplication::arguments();
    if (args.contains(QStringLiteral("--selftest-leduc")))
    {
        const QVariantMap r = toy_nash_solver.solveLeduc(2000);
        const QString s = r.value(QStringLiteral("summaryText")).toString();
        qInfo().noquote() << s;
        return 0;
    }

    QQmlApplicationEngine engine;
    engine.addImportPath(QStringLiteral("qrc:/"));
    engine.rootContext()->setContextProperty(QStringLiteral("appFontFamily"), appFontFamily);
    engine.rootContext()->setContextProperty(QStringLiteral("pokerGame"), &poker_game);
    engine.rootContext()->setContextProperty(QStringLiteral("pokerSolver"), &poker_solver);
    engine.rootContext()->setContextProperty(QStringLiteral("toyNashSolver"), &toy_nash_solver);
    engine.rootContext()->setContextProperty(QStringLiteral("trainingStore"), &training_store);
    engine.rootContext()->setContextProperty(QStringLiteral("trainer"), &trainer);
    engine.rootContext()->setContextProperty(QStringLiteral("sessionStore"), &session_store);

    QObject::connect(&app, &QGuiApplication::aboutToQuit, &poker_game, [&poker_game]() {
        poker_game.savePersistedSettings();
    });
    const QUrl mainUrl(QStringLiteral("qrc:/Main.qml"));
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [mainUrl](QObject *obj, const QUrl &objUrl) {
            if (!obj && mainUrl == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);
    engine.load(mainUrl);

    if (engine.rootObjects().isEmpty())
        return -1;

    // After the scene tree is built, bind the Game Page (not the window) and start hand.
    QTimer::singleShot(400, &app, [&engine, &poker_game]() {
        QObject *const win = engine.rootObjects().isEmpty() ? nullptr : engine.rootObjects().first();
        QObject *const gp = win ? win->findChild<QObject *>(QStringLiteral("game_screen")) : nullptr;
        if (!gp)
        {
            qWarning() << "game_screen not found; table UI will not update.";
            return;
        }
        poker_game.setRootObject(gp);
        poker_game.beginNewHand();
    });

    return app.exec();
}
