#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <image_reader.h>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;

    qmlRegisterType<ImageReader>("com.musclecomputing", 1, 0, "ImageReader");

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("TraderUI", "Main");

    return app.exec();
}
