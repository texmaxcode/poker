#ifndef MUSCLE_COMPUTING_STORAGE_H
#define MUSCLE_COMPUTING_STORAGE_H

#include <memory>

#include <sqlite_orm/sqlite_orm.h>

struct User
{
    int id;
    std::string name;
    std::string email;
    std::string config_path;
};

inline auto initStorage(const std::string &path)
{
    using namespace sqlite_orm;
    return make_storage(path,
                        make_table("users",
                                   make_column("id", &User::id, primary_key()),
                                   make_column("name", &User::name),
                                   make_column("config_path", &User::config_path)));
}

// Just getting the type here.
using Storage = decltype(initStorage(""));

#define DATA_FILE "game_view_studio.data"

class simulator_storage
{
public:
    Storage storage;
    simulator_storage(): storage(initStorage(DATA_FILE)) {};
    void test_orm();
};

#endif // MUSCLE_COMPUTING_STORAGE_H
