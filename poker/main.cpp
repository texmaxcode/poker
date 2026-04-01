#include <QCoreApplication>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTimer>

#include "game.hpp"
#include "poker_solver.hpp"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Texas Hold'em Gym"));

    game poker_game;
    PokerSolver poker_solver;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("pokerGame"), &poker_game);
    engine.rootContext()->setContextProperty(QStringLiteral("pokerSolver"), &poker_solver);
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
