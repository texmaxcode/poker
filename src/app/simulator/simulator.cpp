#include "simulator.hpp"
#include "storage.hpp"

QString simulator::get_version()
{
  return version;
}

void simulator::test_orm()
{
  store.test_orm();
}
