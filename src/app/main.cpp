#include "mainwindow.h"

#include <QApplication>

#include <image_reader.h>

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
    MainWindow w;
    show_image();
    w.show();
    return a.exec();
}
