#include "storage.hpp"

#include <iostream>

void simulator_storage::test_orm()
{
    using namespace sqlite_orm;
    using std::cout;
    using std::endl;

    storage.sync_schema();

    storage.remove_all<User>();

    //  insert values..
    storage.insert(User{-1, "Max", "max@musclecomputing.com", "test/config.txt"});
    storage.insert(User{-1, "Test", "test@musclecomputing.com", "special/config.txt"});

    cout << "Users count = " << storage.count<User>() << endl;

    //  iterate through heros - iteration takes less memory than `get_all` because
    //  iteration fetches row by row once it is needed. If you break at any iteration
    //  statement will be cleared without fetching remaining rows.
    for (auto &user : storage.iterate<User>())
    {
        cout << "user = " << storage.dump(user) << endl;
    }

    cout << "====" << endl;

    //  one can iterate with custom WHERE conditions..
    for (auto &user : storage.iterate<User>(where(c(&User::name) == "Max")))
    {
        cout << "user = " << storage.dump(user) << endl;
    }

    cout << "Users with LENGTH(name) < 6 :" << endl;
    for (auto &user : storage.iterate<User>(where(length(&User::name) < 6)))
    {
        cout << "user = " << storage.dump(user) << endl;
    }

    std::vector<User> usersByAlgorithm;
    usersByAlgorithm.reserve(static_cast<size_t>(storage.count<User>()));
    {
        auto view = storage.iterate<User>();
        std::copy(view.begin(), view.end(), std::back_inserter(usersByAlgorithm));
    }
    cout << "usersByAlgorithm.size = " << usersByAlgorithm.size() << endl;
}
