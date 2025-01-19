#ifndef IMAGE_READER_H
#define IMAGE_READER_H

#include <QObject>

class ImageReader: public QObject {
    Q_OBJECT
public:
  explicit ImageReader(QObject* parent = 0): QObject(parent) {}
  Q_INVOKABLE void show_image();
};

#endif // IMAGE_READER_H