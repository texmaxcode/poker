#ifndef MUSCLE_COMPUTING_UTILS_H
#define MUSCLE_COMPUTING_UTILS_H

#include <string>
#include <sstream>

template <typename T>
std::string to_string(const T& value)
{
  std::ostringstream ss;
  ss << value;
  return ss.str();
}

template <typename Enumeration>
auto as_integer(Enumeration const value)
  -> typename std::underlying_type<Enumeration>::type
{
    return static_cast<typename std::underlying_type<Enumeration>::type>(value);
}

#endif // MUSCLE_COMPUTING_UTILS_H