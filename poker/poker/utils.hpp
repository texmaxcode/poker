#ifndef TEXAS_HOLDEM_GYM_UTILS_H
#define TEXAS_HOLDEM_GYM_UTILS_H

#include <type_traits>

template <typename Enumeration>
auto as_integer(Enumeration const value)
    -> typename std::underlying_type<Enumeration>::type
{
  return static_cast<typename std::underlying_type<Enumeration>::type>(value);
}

#endif // TEXAS_HOLDEM_GYM_UTILS_H