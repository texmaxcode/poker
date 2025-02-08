#include <QGuiApplication>
#include <QQmlApplicationEngine>

#include "poker_simulator.hpp"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;

    qmlRegisterType<simulator>("com.musclecomputing", 1, 0, "Simulator");
    app.setApplicationName(QString("Texas Hold'em Solver"));

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("SolverUI", "Main");

    return app.exec();
}
