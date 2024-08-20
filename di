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
[![Version](https://img.shields.io/github/v/release/qlibs/di)](https://github.com/qlibs/di/releases)
[![Build](https://img.shields.io/badge/build-green.svg)](
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

#include <cstdint>
#include <utility>
#include <type_traits>
#include <memory>

namespace di::inline v1_0_0 {
namespace type_traits {
template<class T> struct naked { using type = T; };
template<class T> requires (not std::is_same_v<std::remove_cvref_t<std::remove_pointer_t<T>>, T>)
struct naked<T> { using type = typename naked<std::remove_cvref_t<std::remove_pointer_t<T>>>::type; };
template<class T> requires requires(T t) { typename T::element_type; *t; t.get(); }
struct naked<T> { using type = typename naked<typename T::element_type>::type; };
template<class T> using naked_t = typename naked<T>::type;
namespace detail {
template<class T> struct provider { using value_type = T; };
template<class, size_t> struct arg { friend constexpr auto get(arg); };
template<class T, class R> struct bind { friend constexpr auto get(T) { return provider<R>{}; } };
template<class T, class R> concept copy_or_move = std::is_same_v<T, std::remove_cvref_t<R>>;
template<class T, size_t N> struct any final {
  template<class R> requires (not copy_or_move<T, R>) operator R() noexcept(noexcept(bind<arg<T, N>, R>{}));
  template<class R> requires (not copy_or_move<T, R>) operator R&() const noexcept(noexcept(bind<arg<T, N>, R&>{}));
  template<class R> requires (not copy_or_move<T, R>) operator const R&() const noexcept(noexcept(bind<arg<T, N>, const R&>{}));
  template<class R> requires (not copy_or_move<T, R>) operator R&&() const noexcept(noexcept(bind<arg<T, N>, R&&>{}));
};
} // namespace detail
template<class...> struct type_list{};
template<class T> struct ctor_args { using type = type_list<>; };
template<class T> requires std::is_class_v<T>
struct ctor_args<T> {
  static constexpr auto size = 16u;
  template<size_t... Ns> static constexpr auto args(std::index_sequence<Ns...>) {
    if constexpr (requires { T{detail::any<T, Ns>{}...}; }) {
      return type_list<typename decltype(get(detail::arg<T, Ns>{}))::value_type...>{};
    } else if constexpr (sizeof...(Ns)) {
      return args(std::make_index_sequence<sizeof...(Ns) - 1u>{});
    } else {
      return type_list{};
    }
  }
  using type = decltype(args(std::make_index_sequence<size>{}));
};

template<class T> using ctor_args_t = typename ctor_args<T>::type;
template<class T> inline constexpr ctor_args_t<T> ctor_args_v{};
} // namespace type_traits

template<class...> concept _ = true;
template<class T, template<class...> class Trait>
concept trait = Trait<T>::value;
template<class T, template<class...> class R>
concept is_a = std::is_same_v<R<typename T::element_type>, T>;
namespace detail {
struct invocable_base { void operator()(); };
template<class T> struct invocable_impl : T, invocable_base {};
} // namespace detail
template<class T> concept invocable = std::is_class_v<T> and not requires { &detail::invocable_impl<T>::operator(); };

template<class... Ts> struct overload : Ts... {
  using value_type = type_traits::type_list<>;
  using Ts::operator()...;
};
template<class... Ts> overload(Ts...) -> overload<Ts...>;

template<class T> T failed();
template<class T> [[nodiscard]] constexpr auto invoke(auto&& self) -> T {
  if constexpr (requires { self.template operator()<T>(self); }) {
    return self.template operator()<T>(self);
  } else {
    return failed<T>();
  }
}

template<auto N, class TSelf>
auto parent(TSelf) -> typename TSelf::template parent<N>::type;

template<class T, class... Ts>
struct wrapper : T {
  constexpr wrapper(T t) : T{t} {}
  using value_type = type_traits::type_list<Ts...>;

  template<auto N> struct parent {
    using type = __type_pack_element<sizeof...(Ts) + N, Ts...>;;
  };
};

template<class T, class... TParents, class... TArgs>
[[nodiscard]] constexpr auto make(TArgs&&... args) -> decltype(T{static_cast<T&&>(args)...}) {
  return T{static_cast<T&&>(args)...};
}

template<class T, class Fn>
[[nodiscard]] constexpr auto make(Fn fn) -> decltype(auto) requires (invocable<Fn> and not requires { T{fn}; }) {
  return [&]<class... Ts>(type_traits::type_list<Ts...>) {
    using type = type_traits::naked_t<T>;
    if constexpr (std::is_class_v<type>) {
      return [&]<template<class...> class TList, class... TArgs>(TList<TArgs...>) -> decltype(auto) {
        return [&]<size_t... Ns>(std::index_sequence<Ns...>) -> decltype(auto) {
          return T{invoke<TArgs>(wrapper<Fn, Ts..., T>{fn})...};
        }(std::make_index_sequence<sizeof...(TArgs)>{});
      }(type_traits::ctor_args_v<type>);
    } else {
      return invoke<T>(wrapper<Fn, Ts..., T>{fn});
    }
  }(typename Fn::value_type{});
}
// make_shared
// make_unique
} // namespace di

#ifndef NTEST
static_assert(([] {
  // di::type_traits
  {
    // ctor_args_t
    {
      using di::type_traits::type_list;

      static_assert(std::is_same_v<type_list<>, di::type_traits::ctor_args_t<void>>);
      static_assert(std::is_same_v<type_list<>, di::type_traits::ctor_args_t<int>>);
      static_assert(std::is_same_v<type_list<>, di::type_traits::ctor_args_t<const int&>>);
      static_assert(std::is_same_v<type_list<>, di::type_traits::ctor_args_t<void*>>);

      struct empty{};
      static_assert(std::is_same_v<type_list<>, di::type_traits::ctor_args_t<empty>>);

      struct trivial{ constexpr trivial() = default; };
      static_assert(std::is_same_v<type_list<>, di::type_traits::ctor_args_t<trivial>>);

      struct a1 { int i; };
      static_assert(std::is_same_v<type_list<int>, di::type_traits::ctor_args_t<a1>>);

      struct a2 { const int* i; float f{}; };
      static_assert(std::is_same_v<type_list<const int*, float>, di::type_traits::ctor_args_t<a2>>);

      struct c0{ constexpr explicit(true) c0(empty) { }; };
      static_assert(std::is_same_v<type_list<empty>, di::type_traits::ctor_args_t<c0>>);

      struct c1 { c1(int) { } };
      static_assert(std::is_same_v<type_list<int>, di::type_traits::ctor_args_t<c1>>);

      struct c2 { c2(const int&) { } };
      static_assert(std::is_same_v<type_list<const int&>, di::type_traits::ctor_args_t<c2>>);

      struct c3 { c3(const int&, empty*) { } };
      static_assert(std::is_same_v<type_list<const int&, empty*>, di::type_traits::ctor_args_t<c3>>);

      struct c4 { c4(const int&, const empty*, float) { } };
      static_assert(std::is_same_v<type_list<const int&, const empty*, float>, di::type_traits::ctor_args_t<c4>>);

      struct c5 { constexpr c5(int, int, int, int) noexcept { } };
      static_assert(std::is_same_v<type_list<int, int, int, int>, di::type_traits::ctor_args_t<c5>>);

      struct c6 { constexpr c6(int, int, int, int, int,
                               int, int, int, int, int,
                               int, int, int, int, int) throw() { } };
      static_assert(std::is_same_v<
        type_list<int, int, int, int, int,
                  int, int, int, int, int,
                  int, int, int, int, int>, di::type_traits::ctor_args_t<c6>>);
    }
  }

  // di::overload
  {
    static_assert(0u == di::overload{[](auto... ts) { return sizeof...(ts); }}());
    static_assert(1u == di::overload{[](auto... ts) { return sizeof...(ts); }}(1));
    static_assert(2u == di::overload{[](auto... ts) { return sizeof...(ts); }}(1, 2));
    static_assert(42 == di::overload{[](int i) { return i; }}(42));
    static_assert(42 == di::overload{[](int i) { return i; }, [](auto a) { return a; }}(42));
    static_assert('_' == di::overload{[](int i) { return i; }, [](auto a) { return a; }}('_'));
  }
}(), true));
#endif // NTEST
