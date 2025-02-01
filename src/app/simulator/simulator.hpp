#ifndef MUSCLE_COMPUTING_SIMULATOR_H
#define MUSCLE_COMPUTING_SIMULATOR_H

#include <string>
#include <QObject>
#include "storage.hpp"

class simulator: public QObject {
  Q_OBJECT
  QString version {"0.0.1"};
  simulator_storage store;
public:
  explicit simulator(QObject* parent = 0): QObject(parent) {}
  Q_INVOKABLE QString get_version();
  Q_INVOKABLE void test_orm();
};

#endif // MUSCLE_COMPUTING_SIMULATOR_H
