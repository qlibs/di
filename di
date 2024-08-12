// <!--
// The MIT License (MIT)
//
// Copyright (c) 2024 Kris Jusiak <kris@jusiak.net>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
#if 0
// -->
[Overview](#Overview) / [Examples](#Examples) / [API](#API) / [FAQ](#FAQ)

## DI: Dependency Injection library

[![MIT Licence](http://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/license/mit)
[![Version](https://badge.fury.io/gh/qlibs%2Fdi.svg)](https://github.com/qlibs/di/releases)
[![build](https://img.shields.io/badge/build-blue.svg)]()
[![Try it online](https://img.shields.io/badge/try%20it-online-blue.svg)](https://godbolt.org/z/E4s3EqWrM)

  > https://en.wikipedia.org/wiki/Dependency_injection

### Use cases

- Fully customizable generic factories


### Features

- Single header (https://raw.githubusercontent.com/qlibs/di/main/di - for integration see [FAQ](#faq))
- Minimal [API](#api)
  - Unified way with different polymorphism styles (`concepts, variant, type_erasure, CRTP, virtual`) as well as aggregates, classes, etc.
  - Constructor order and types changes agnostic (Simplifies integration with third party libraries)
  - Testing (Different bindigns for `production` and `testing`)
  - Policies, Logging
- Verifies itself upon include (can be disabled with `-DNTEST` - see [FAQ](#faq))

### Requirements

- C++20 ([clang++10+, g++10+](https://en.cppreference.com/w/cpp/compiler_support))

---

### Overview

---

### Examples

> DIY - Dependency Injection Yourself

---

### FAQ

- How to integrate with CMake/CPM?

    ```
    CPMAddPackage(
      Name di
      GITHUB_REPOSITORY qlibs/di
      GIT_TAG v1.0.0
    )
    add_library(di INTERFACE)
    target_include_directories(mp SYSTEM INTERFACE ${mp_SOURCE_DIR})
    add_library(qlibs::di ALIAS di)
    ```

    ```
    target_link_libraries(${PROJECT_NAME} qlibs::di)
    ```

- Acknowledgments

<!--
#endif

#pragma once

#ifdef __GNUC__
#pragma GCC system_header
#endif

namespace di::inline v1_0_0 {
using size_t = decltype(sizeof(int));
namespace utility {
template<class T, T...> struct integer_sequence { };
template<size_t... Ns> using index_sequence = integer_sequence<size_t, Ns...>;
template<size_t N> using make_index_sequence =
#if defined(__clang__) || defined(_MSC_VER)
  __make_integer_seq<integer_sequence, size_t, N>;
#else
   index_sequence<__integer_pack(N)...>;
#endif
template<class...> struct type_list{};
template<class... Ts> struct overload : Ts... { using Ts::operator()...; };
template<class... Ts> overload(Ts...) -> overload<Ts...>;

} // namespace utility
namespace type_traits {
template<class...> inline constexpr auto is_same_v = false;
template<class T> inline constexpr auto is_same_v<T, T> = true;
template<class T> struct remove_pointer { using type = T; };
template<class T> struct remove_pointer<T*> { using type = T; };
template<class T> struct remove_pointer<T* const> { using type = T; };
template<class T> struct remove_pointer<T* volatile> { using type = T; };
template<class T> struct remove_pointer<T* const volatile> { using type = T; };
template<class T> using remove_pointer_t = typename remove_pointer<T>::type;
template<class T> struct remove_reference { using type = T; };
template<class T> struct remove_reference<T&> { using type = T; };
template<class T> struct remove_reference<T&&> { using type = T; };
template<class T> using remove_reference_t = typename remove_reference<T>::type;
template<class T> struct remove_cv { using type = T; };
template<class T> struct remove_cv<const T> { using type = T; };
template<class T> struct remove_cv<volatile T> { using type = T; };
template<class T> struct remove_cv<const volatile T> { using type = T; };
template<class T> using remove_cv_t = typename remove_cv<T>::type;
template<class T> using remove_cvref_t = remove_cv_t<remove_reference_t<T>>;
namespace detail {
template<class T> struct provider { using value_type = T; };
template<class, size_t> struct arg { friend constexpr auto get(arg); };
template<class T, class R> struct bind { friend constexpr auto get(T) { return provider<R>{}; } };
template<class T, class R> concept copy_or_move = type_traits::is_same_v<T, type_traits::remove_cvref_t<R>>;
template<class T, size_t N> struct any final {
  template<class R> requires (not copy_or_move<T, R>) operator R() noexcept(noexcept(bind<arg<T, N>, R>{}));
  template<class R> requires (not copy_or_move<T, R>) operator R&() const noexcept(noexcept(bind<arg<T, N>, R&>{}));
  template<class R> requires (not copy_or_move<T, R>) operator const R&() const noexcept(noexcept(bind<arg<T, N>, const R&>{}));
  template<class R> requires (not copy_or_move<T, R>) operator R&&() const noexcept(noexcept(bind<arg<T, N>, R&&>{}));
};
} // namespace detail
template<class T> struct ctor_args { using type = utility::type_list<>; };
template<class T> requires __is_class(T)
struct ctor_args<T> {
  static constexpr auto size = 16u;
  template<size_t... Ns> static constexpr auto args(utility::index_sequence<Ns...>) {
    if constexpr (requires { T{detail::any<T, Ns>{}...}; }) {
      return utility::type_list<typename decltype(get(detail::arg<T, Ns>{}))::value_type...>{};
    } else if constexpr (sizeof...(Ns)) {
      return args(utility::make_index_sequence<sizeof...(Ns) - 1u>{});
    } else {
      return utility::type_list{};
    }
  }
  using type = decltype(args(utility::make_index_sequence<size>{}));
};

template<class T> using ctor_args_t = typename ctor_args<type_traits::remove_cvref_t<T>>::type;
template<class T> inline constexpr ctor_args_t<T> ctor_args_v{};

template<class T, T Value>
struct integral_constant {
  using value_type = T;
  using type = integral_constant;
  static constexpr T value = Value;
  [[nodiscard]] constexpr operator value_type() const noexcept { return value; }
  [[nodiscard]] constexpr value_type operator()() const noexcept { return value; }
};
} // namespace type_traits

namespace detail {
template<class T, size_t N, class... Ts, class... TArgs>
[[nodiscard]] constexpr auto invoke(auto&& t, auto&& fn, utility::type_list<TArgs...>) -> decltype(auto) {
  return [&]<size_t... Ns>(utility::index_sequence<Ns...>) -> decltype(auto) {
    constexpr auto id = []([[maybe_unused]] const size_t n) -> size_t { return N ? N : n; };
    if constexpr (requires { fn.template operator()<T>(t.template operator()<TArgs>()...); }) {
      return fn.template operator()<T>(t.template operator()<TArgs>()...);
    } else if constexpr (requires { fn.template operator()<T>(t.template operator()<TArgs, Ts...>()...); }) {
      return fn.template operator()<T>(t.template operator()<TArgs, Ts...>()...);
    } else if constexpr (requires { fn.template operator()<T>(t.template operator()<TArgs, type_traits::integral_constant<size_t, id(Ns)>>()...); }) {
      return fn.template operator()<T>(t.template operator()<TArgs, type_traits::integral_constant<size_t, id(Ns)>>()...);
    } else if constexpr (requires { fn.template operator()<T>(t.template operator()<TArgs, Ts...>(t)...); }) {
      return fn.template operator()<T>(t.template operator()<TArgs, Ts...>(t)...);
    } else if constexpr (requires { fn.template operator()<T>(t.template operator()<TArgs, type_traits::integral_constant<size_t, id(Ns)>>(t)...); }) {
      return fn.template operator()<T>(t.template operator()<TArgs, type_traits::integral_constant<size_t, id(Ns)>>()>(t)...);
    } else {
      return fn.template operator()<T>(t.template operator()<TArgs, type_traits::integral_constant<size_t, id(Ns)>, Ts...>(t)...);
    }
  }(utility::make_index_sequence<sizeof...(TArgs)>{});
}
} // namespace detail

template<class T>
[[nodiscard]] constexpr auto create(auto&& t) -> decltype(auto) {
  if constexpr (requires { t.template operator()<T>(); }) {
    return t.template operator()<T>();
  } else if constexpr (requires { t.template operator()<T>(t); }) {
    return t.template operator()<T>(t);
  } else {
    return t.template operator()<T, type_traits::integral_constant<size_t, {}>>(t);
  }
}

template<class T, class... Ts>
[[nodiscard]] constexpr auto create(auto&& t, auto&& fn) -> decltype(auto) {
  if constexpr (__is_class(type_traits::remove_cvref_t<type_traits::remove_pointer_t<T>>)) {
    return [&]<template<class...> class TList, class... TArgs>(TList<TArgs...>) -> decltype(auto) {
      return detail::invoke<T, {}, T, Ts...>(t, fn, utility::type_list<TArgs...>{});
    }(type_traits::ctor_args_v<T>);
  } else {
    return detail::invoke<T, {}, Ts...>(t, fn, utility::type_list<T>{});
  }
}
} // namespace di

#ifndef NTEST
static_assert(([] {
  // di::utility
  {
    // integer_sequence
    {
      static_assert([](di::utility::integer_sequence<di::size_t>){ return true; }(di::utility::make_index_sequence<0>{}));
      static_assert([](di::utility::integer_sequence<di::size_t, 0>){ return true; }(di::utility::make_index_sequence<1>{}));
      static_assert([](di::utility::integer_sequence<di::size_t, 0, 1>){ return true; }(di::utility::make_index_sequence<2>{}));
      static_assert([](di::utility::index_sequence<>){ return true; }(di::utility::make_index_sequence<0>{}));
      static_assert([](di::utility::index_sequence<0>){ return true; }(di::utility::make_index_sequence<1>{}));
      static_assert([](di::utility::index_sequence<0, 1>){ return true; }(di::utility::make_index_sequence<2>{}));
    }

    // overload
    {
      static_assert(0u == di::utility::overload{[](auto... ts) { return sizeof...(ts); }}());
      static_assert(1u == di::utility::overload{[](auto... ts) { return sizeof...(ts); }}(1));
      static_assert(2u == di::utility::overload{[](auto... ts) { return sizeof...(ts); }}(1, 2));
      static_assert(42 == di::utility::overload{[](int i) { return i; }}(42));
      static_assert(42 == di::utility::overload{[](int i) { return i; }, [](auto a) { return a; }}(42));
      static_assert('_' == di::utility::overload{[](int i) { return i; }, [](auto a) { return a; }}('_'));
    }
  }

  // di::type_traits
  {
    // is_same_v
    {
      static_assert(not di::type_traits::is_same_v<int, void>);
      static_assert(not di::type_traits::is_same_v<void, int>);
      static_assert(not di::type_traits::is_same_v<void*, int>);
      static_assert(not di::type_traits::is_same_v<int, const int>);
      static_assert(di::type_traits::is_same_v<void, void>);
      static_assert(di::type_traits::is_same_v<int, int>);
      static_assert(di::type_traits::is_same_v<const int&, const int&>);
      static_assert(di::type_traits::is_same_v<const void*, const void*>);
    }

    using di::type_traits::is_same_v;

    // remove_pointer_t
    {
      static_assert(is_same_v<void, di::type_traits::remove_pointer_t<void>>);
      static_assert(is_same_v<int, di::type_traits::remove_pointer_t<int>>);
      static_assert(is_same_v<int&, di::type_traits::remove_pointer_t<int&>>);
      static_assert(is_same_v<int, di::type_traits::remove_pointer_t<int*>>);
      static_assert(is_same_v<int*, di::type_traits::remove_pointer_t<int**>>);
      static_assert(is_same_v<const int, di::type_traits::remove_pointer_t<const int*>>);
      static_assert(is_same_v<const volatile int, di::type_traits::remove_pointer_t<const volatile int*>>);
    }

    // remove_reference_t
    {
      static_assert(is_same_v<void, di::type_traits::remove_reference_t<void>>);
      static_assert(is_same_v<int, di::type_traits::remove_reference_t<int>>);
      static_assert(is_same_v<int, di::type_traits::remove_reference_t<int&>>);
      static_assert(is_same_v<int, di::type_traits::remove_reference_t<int&&>>);
      static_assert(is_same_v<const int, di::type_traits::remove_reference_t<const int&>>);
      static_assert(is_same_v<const int, di::type_traits::remove_reference_t<const int&&>>);
    }

    // remove_cv_t
    {
      static_assert(is_same_v<void, di::type_traits::remove_cv_t<void>>);
      static_assert(is_same_v<int, di::type_traits::remove_cv_t<const int>>);
      static_assert(is_same_v<int, di::type_traits::remove_cv_t<volatile int>>);
      static_assert(is_same_v<int, di::type_traits::remove_cv_t<const volatile int>>);
      static_assert(is_same_v<const int&, di::type_traits::remove_cv_t<const int&>>);
      static_assert(is_same_v<volatile int&&, di::type_traits::remove_cv_t<volatile int&&>>);
      static_assert(is_same_v<volatile const void*, di::type_traits::remove_cv_t<volatile const void*>>);
    }

    // remove_cvref_t
    {
      static_assert(is_same_v<void, di::type_traits::remove_cvref_t<void>>);
      static_assert(is_same_v<int, di::type_traits::remove_cvref_t<int>>);
      static_assert(is_same_v<int, di::type_traits::remove_cvref_t<int&>>);
      static_assert(is_same_v<int, di::type_traits::remove_cvref_t<int&&>>);
      static_assert(is_same_v<int, di::type_traits::remove_cvref_t<const int&>>);
      static_assert(is_same_v<int, di::type_traits::remove_cvref_t<const int&&>>);
      static_assert(is_same_v<void, di::type_traits::remove_cvref_t<void>>);
      static_assert(is_same_v<int, di::type_traits::remove_cvref_t<const int>>);
      static_assert(is_same_v<int, di::type_traits::remove_cvref_t<volatile int>>);
      static_assert(is_same_v<int, di::type_traits::remove_cvref_t<const volatile int>>);
      static_assert(is_same_v<int, di::type_traits::remove_cvref_t<const int&>>);
      static_assert(is_same_v<int, di::type_traits::remove_cvref_t<volatile int&&>>);
      static_assert(is_same_v<volatile const void*, di::type_traits::remove_cvref_t<volatile const void*>>);
    }

    // ctor_args_t
    {
      using di::type_traits::is_same_v;
      using di::utility::type_list;

      static_assert(is_same_v<type_list<>, di::type_traits::ctor_args_t<void>>);
      static_assert(is_same_v<type_list<>, di::type_traits::ctor_args_t<int>>);
      static_assert(is_same_v<type_list<>, di::type_traits::ctor_args_t<const int&>>);
      static_assert(is_same_v<type_list<>, di::type_traits::ctor_args_t<void*>>);

      struct empty{};
      static_assert(is_same_v<type_list<>, di::type_traits::ctor_args_t<empty>>);

      struct trivial{ constexpr trivial() = default; };
      static_assert(is_same_v<type_list<>, di::type_traits::ctor_args_t<trivial>>);

      struct a1 { int i; };
      static_assert(is_same_v<type_list<int>, di::type_traits::ctor_args_t<a1>>);

      struct a2 { const int* i; float f{}; };
      static_assert(is_same_v<type_list<const int*, float>, di::type_traits::ctor_args_t<a2>>);

      struct c0{ constexpr explicit(true) c0(empty) { }; };
      static_assert(is_same_v<type_list<empty>, di::type_traits::ctor_args_t<c0>>);

      struct c1 { c1(int) { } };
      static_assert(is_same_v<type_list<int>, di::type_traits::ctor_args_t<c1>>);

      struct c2 { c2(const int&) { } };
      static_assert(is_same_v<type_list<const int&>, di::type_traits::ctor_args_t<c2>>);

      struct c3 { c3(const int&, empty*) { } };
      static_assert(is_same_v<type_list<const int&, empty*>, di::type_traits::ctor_args_t<c3>>);

      struct c4 { c4(const int&, const empty*, float) { } };
      static_assert(is_same_v<type_list<const int&, const empty*, float>, di::type_traits::ctor_args_t<c4>>);

      struct c5 { constexpr c5(int, int, int, int) noexcept { } };
      static_assert(is_same_v<type_list<int, int, int, int>, di::type_traits::ctor_args_t<c5>>);

      struct c6 { constexpr c6(int, int, int, int, int,
                               int, int, int, int, int,
                               int, int, int, int, int) throw() { } };
      static_assert(is_same_v<
        type_list<int, int, int, int, int,
                  int, int, int, int, int,
                  int, int, int, int, int>, di::type_traits::ctor_args_t<c6>>);
    }
  }
}(), true));
#endif // NTEST
