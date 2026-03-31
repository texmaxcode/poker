#include <QGuiApplication>
#include <QQuickView>

#include "game.hpp"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QString("Texas Hold'em Solver"));

    QQuickView view;
    view.setSource(QUrl("qrc:/Game.qml"));
    view.setResizeMode(QQuickView::SizeRootObjectToView);

    game poker_game;
    poker_game.setRootObject(view.rootObject());

    view.show();
    return app.exec();

}
