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
[![Build](https://img.shields.io/badge/build-green.svg)](https://godbolt.org/z/fKEcojqze)
[![Try it online](https://img.shields.io/badge/try%20it-online-blue.svg)](https://godbolt.org/z/Pd3GrdfM8)

  > https://en.wikipedia.org/wiki/Dependency_injection

### Use case

- [Generic factories](https://en.wikipedia.org/wiki/Factory_method_pattern)

### Features

- Single header (https://raw.githubusercontent.com/qlibs/di/main/di - for integration see [FAQ](#faq))
- Minimal [API](#api)
  - Unified way for different polymorphism styles (`inheritance, type_erasure, variant, ...`)
  - Constructor deduction for classes and aggregates
  - Constructor order and types changes agnostic (simplifies integration with `third party libraries`)
  - Testing (different bindigns for `production` and `testing`)
  - Policies (APIs with `checked` requirements)
  - Logging/Profiling/Serialization/... (iteration over all `created` objects)
- Verifies itself upon include (can be disabled with `-DNTEST` - see [FAQ](#faq))


### Requirements

- C++20 ([clang++13+, g++11+](https://en.cppreference.com/w/cpp/compiler_support))

---

### Overview

> API ()


---

### Examples

> DIY - Dependency Injection Yourself (https://godbolt.org/z/v597WY8cz)

```cpp
```

----

### API

```cpp
namespace di::inline v1_0_0 {
/**
 * @code
 * struct c1 { c1(int) { } };
 * static_assert(std::is_same_v<type_list<int>, di::ctor_traits<c1>::type>);
 * #endcode
 */
template<class T, std::size_t N = 16u> struct ctor_traits {
  using type = /*unspecified*/;
  template<class... Ts>
  [[nodiscard]] constexpr auto operator()(Ts&&...) const -> T;
};

/**
 * static_assert(di::invocable<decltype([]{})>);
 * static_assert(di::invocable<decltype([](int){})>);
 * static_assert(di::invocable<decltype([](const int&){})>);
 * static_assert(di::invocable<decltype([]<class... Ts>(Ts...){})>);
 * static_assert(di::invocable<decltype([]<auto... >(){})>);
 * static_assert(di::invocable<decltype([](auto...){})>);
 * static_assert(di::invocable<decltype([](...){})>);
 */
template<class T> concept invocable;

/**
 * @code
 * static_assert(not di::is<int, const int>);
 * static_assert(not di::is<int, const int*>);
 * static_assert(not di::is<int, const int*>);
 * static_assert(di::is<void, void>);
 * static_assert(di::is<int, int>);
 * static_assert(di::is<const void*, const void*>);
 * static_assert(di::is<int&&, int&&>);
 * @endcode
 */
template<class TLhs, class TRhs> concept is;

/**
 * @code
 * static_assert(not di::is_a<int, std::shared_ptr>);
 * static_assert(not di::is_a<std::shared_ptr<void>&, std::unique_ptr>);
 * static_assert(not di::is_a<const std::shared_ptr<int>&, std::unique_ptr>);
 * static_assert(not di::is_a<std::shared_ptr<void>, std::unique_ptr>);
 * static_assert(di::is_a<std::shared_ptr<void>, std::shared_ptr>);
 * static_assert(di::is_a<std::shared_ptr<int>, std::shared_ptr>);
 * static_assert(di::is_a<std::unique_ptr<int>, std::unique_ptr>);
 */
template<class T, template<class...> class R> concept is_a;

/**
 * @code
 * static_assert(not di::is_smart_ptr<void>);
 * static_assert(not di::is_smart_ptr<void*>);
 * static_assert(not di::is_smart_ptr<int>);
 * static_assert(not di::is_smart_ptr<const int&>);
 * static_assert(not di::is_smart_ptr<const std::shared_ptr<int>&>);
 * static_assert(di::is_smart_ptr<std::shared_ptr<void>>);
 * static_assert(di::is_smart_ptr<std::shared_ptr<int>>);
 * static_assert(di::is_smart_ptr<std::unique_ptr<int>>);
 */
template<class T> concept is_smart_ptr;

/**
 * @code
 * static_assert(not di::trait<int, std::is_const>);
 * static_assert(di::trait<const int, std::is_const>);
 * static_assert(not di::trait<const int&, std::is_pointer>);
 * static_assert(di::trait<int*, std::is_pointer>);
 * static_assert(not di::trait<int, std::is_class>);
 * static_assert(di::trait<std::shared_ptr<void>, std::is_class>);
 */
template<class T, template<class...> class Trait> concept trait;

/**
 * @code
 * static_assert(42 == di::overload{
 *   [](int i) { return i; },
 *   [](auto a) { return a; }
 * }(42));
 * @endcode
 */
template<class... Ts> struct overload;

/**
 * Injection context
 */
template<class T, class Index, class TParent>
struct provider {
  using value_type = T;
  using parent_type = TParent;
  static constexpr auto index() -> std::size_t;
  static constexpr auto parent() -> parent_type;
  static constexpr auto type() -> value_type;
  static constexpr auto size() -> std::size_t;
  #if defined(REFLECT)
  static constexpr auto name() -> std::string_view;
  #endif
};

/**
 * @code
 * static_assert(42 == di::make<int>(42));
 * @endcode
 */
template<class R, class... Ts>
[[nodiscard]] constexpr auto make(Ts&&... ts) requires requires { R{std::forward<Ts>(ts)...}; };

/**
 * @code
 * static_assert(42 == di::make<int>(
 *   di::overload{
 *     [](di::is<int> auto) { return 42; }
 *   }
 * ));
 * @endcode
 */
template<class R, class T>
[[nodiscard]] constexpr auto make(T&& t) requires invocable<T>;
}
```

---

### FAQ

- How to integrate with [CMake.FetchContent](https://cmake.org/cmake/help/latest/module/FetchContent.html)?

    ```
    include(FetchContent)

    FetchContent_Declare(
      qlibs.di
      GIT_REPOSITORY https://github.com/qlibs/di
      GIT_TAG v1.0.0
    )

    FetchContent_MakeAvailable(qlibs.di)
    ```

    ```
    target_link_libraries(${PROJECT_NAME} PUBLIC qlibs.di);
    ```

- Acknowledgments
  - https://www.youtube.com/watch?v=yVogS4NbL6U, https://www.youtube.com/watch?v=QZkVpZlbM4U

<!--
#endif

#pragma once
#pragma GCC system_header

#include <cstdint>
#include <utility>
#include <type_traits>
#include <memory>

namespace di::inline v1_0_0 {
namespace detail {
template<class...> struct type_list{};
template<class T> struct provider { using value_type = T; };
template<class, std::size_t> struct arg { friend constexpr auto get(arg); };
template<class T, class R> struct bind { friend constexpr auto get(T) { return provider<R>{}; } };
template<class T, class R> concept copy_or_move = std::is_same_v<T, std::remove_cvref_t<R>>;
template<class T, std::size_t N> struct any final {
  template<class R> requires (not copy_or_move<T, R>) operator R() noexcept(noexcept(bind<arg<T, N>, R>{}));
  template<class R> requires (not copy_or_move<T, R>) operator R&() const noexcept(noexcept(bind<arg<T, N>, R&>{}));
  template<class R> requires (not copy_or_move<T, R>) operator const R&() const noexcept(noexcept(bind<arg<T, N>, const R&>{}));
  template<class R> requires (not copy_or_move<T, R>) operator R&&() const noexcept(noexcept(bind<arg<T, N>, R&&>{}));
};
} // namespace detail
template<class T, std::size_t N = 16u> struct ctor_traits {
  using type = detail::type_list<>;
  [[nodiscard]] constexpr auto operator()() const -> T {
    return {};
  }
};
template<class T, std::size_t N> requires (not std::is_class_v<T> and requires(T t) { T{t}; })
struct ctor_traits<T, N> {
  using type = detail::type_list<T>;
  template<class... Ts> [[nodiscard]] constexpr auto operator()(Ts&&... ts) const -> T
    requires requires { T{std::forward<Ts>(ts)...}; } {
    return T{std::forward<Ts>(ts)...};
  }
};
template<class T, std::size_t N> requires std::is_class_v<T>
struct ctor_traits<T, N> {
  template<std::size_t... Ns> static constexpr auto args(std::index_sequence<Ns...>) {
    if constexpr (requires { T{detail::any<T, Ns>{}...}; } and (requires { get(detail::arg<T, Ns>{}); } and ...)) {
      return detail::type_list<typename decltype(get(detail::arg<T, Ns>{}))::value_type...>{};
    } else if constexpr (sizeof...(Ns)) {
      return args(std::make_index_sequence<sizeof...(Ns) - 1u>{});
    } else {
      return detail::type_list{};
    }
  }
  using type = decltype(args(std::make_index_sequence<N>{}));
  template<class... Ts> [[nodiscard]] constexpr auto operator()(Ts&&... ts) const -> T
    requires requires { T{std::forward<Ts>(ts)...}; } {
    return T{std::forward<Ts>(ts)...};
  }
};
template<class T, std::size_t N>
struct ctor_traits<std::shared_ptr<T>, N> {
  using type = detail::type_list<T>;
  [[nodiscard]] constexpr auto operator()(auto&& t) const -> std::shared_ptr<T>
    requires requires { std::make_shared<std::remove_cvref_t<decltype(t)>>(std::forward<decltype(t)>(t)); } {
    return std::make_shared<std::remove_cvref_t<decltype(t)>>(std::forward<decltype(t)>(t));
  }
};
template<class T, std::size_t N>
struct ctor_traits<std::unique_ptr<T>, N> {
  using type = detail::type_list<T>;
  [[nodiscard]] constexpr auto operator()(auto&& t) const -> std::shared_ptr<T>
    requires requires { std::make_unique<std::remove_cvref_t<decltype(t)>>(std::forward<decltype(t)>(t)); } {
    return std::make_unique<std::remove_cvref_t<decltype(t)>>(std::forward<decltype(t)>(t));
  }
};
namespace detail {
struct invocable_base { void operator()(); };
template<class T> struct invocable_impl : T, invocable_base {};
template<class, class T> struct value_type { using type = T; };
template<class T, class R> requires requires(T t) { typename T::value_type; typename T::parent_type; t.index(); t.size(); }
struct value_type<T, R> { using type = typename T::value_type; };
template<class T>
using value_type_t = typename value_type<std::remove_cvref_t<std::remove_pointer_t<T>>, T>::type;
} // namespace detail
template<class T> concept invocable =
  std::is_class_v<std::remove_cvref_t<T>> and
  not requires { &detail::invocable_impl<std::remove_cvref_t<T>>::operator(); };
template<class TLhs, class TRhs> concept is = std::is_same_v<detail::value_type_t<TLhs>, TRhs>;
template<class T, template<class...> class R>
concept is_a = std::is_same_v<R<typename detail::value_type_t<T>::element_type>, detail::value_type_t<T>>;
template<class T> concept is_smart_ptr =
  requires(detail::value_type_t<T> t) { t.get(); typename detail::value_type_t<T>::element_type; };
template<class T, template<class...> class Trait>
concept trait = Trait<detail::value_type_t<T>>::value;

template<class... Ts> struct overload : Ts... { using Ts::operator()...; };
template<class... Ts> overload(Ts...) -> overload<Ts...>;

template<class R, class...> auto error(auto&&...) -> R;
template<class T, class Index, class TParent>
struct provider : TParent {
  using value_type = T;
  using parent_type = TParent;

  static constexpr auto index() -> std::size_t { return Index::value; }
  static constexpr auto parent() -> parent_type;
  static constexpr auto type() -> value_type;
  static constexpr auto size() -> std::size_t {
    if constexpr (requires { parent_type::size(); }) {
      return 1u + parent_type::size();
    } else {
      return 0u;
    }
  }

  #if defined(REFLECT_ENUM_MIN) and defined(REFLECT_ENUM_MAX)
  template<class TParent_ = parent_type>
  static constexpr auto name() -> decltype(reflect::member_name<Index::value, typename TParent_::value_type>()) {
    return reflect::member_name<Index::value, typename TParent_::value_type>();
  }
  #endif
};

template<class R, class... Ts>
[[nodiscard]] constexpr auto make(Ts&&... ts)
  requires requires { R{std::forward<Ts>(ts)...}; } {
  return ctor_traits<R>{}(std::forward<Ts>(ts)...);
}
template<class R, class T>
[[nodiscard]] constexpr auto make(T&& t_) -> decltype(auto)
  requires (invocable<T> and not requires { R{std::forward<T>(t_)}; }) {
  auto&& t = [&] -> decltype(auto) {
    if constexpr (not requires { typename std::remove_cvref_t<T>::parent_type; }) {
      return provider<R, std::integral_constant<std::size_t, 0u>, std::remove_cvref_t<T>>{std::forward<T>(t_)};
    } else {
      return std::forward<T>(t_);
    }
  }();
  const auto make = [&]<template<class...> class TList, class... Ts>(TList<Ts...>) -> decltype(auto) {
    return [&]<std::size_t... Ns>(std::index_sequence<Ns...>) -> decltype(auto) {
      return ctor_traits<R>{}(
        t(provider<Ts, std::integral_constant<std::size_t, Ns>, std::remove_cvref_t<decltype(t)>>{std::forward<decltype(t)>(t)})...
      );
    }(std::make_index_sequence<sizeof...(Ts)>{});
  };
  if constexpr (requires { typename std::remove_cvref_t<decltype(t)>::parent_type::value_type; }) {
    if constexpr (std::is_same_v<R, typename std::remove_cvref_t<decltype(t)>::parent_type::value_type>) {
      return error<R>(t);
    } else {
      return make(typename ctor_traits<R>::type{});
    }
  } else {
    return make(typename ctor_traits<R>::type{});
  }
}
template<class T>
[[nodiscard]] constexpr auto make(T&& t) -> decltype(di::make<typename std::remove_cvref_t<decltype(t)>::value_type>(t)) {
  return di::make<typename std::remove_cvref_t<decltype(t)>::value_type>(t);
}
} // namespace di

#ifndef NTEST
static_assert(([] {
  // di::ctor_traits
  {
    using di::detail::type_list;

    static_assert(std::is_same_v<type_list<>, di::ctor_traits<void>::type>);
    static_assert(std::is_same_v<type_list<int>, di::ctor_traits<int>::type>);

    struct empty{};
    static_assert(std::is_same_v<type_list<>, di::ctor_traits<empty>::type>);

    struct trivial{ constexpr trivial() = default; };
    static_assert(std::is_same_v<type_list<>, di::ctor_traits<trivial>::type>);

    struct a1 { int i; };
    static_assert(std::is_same_v<type_list<int>, di::ctor_traits<a1>::type>);

    struct a2 { const int* i; float f{}; };
    static_assert(std::is_same_v<type_list<const int*, float>, di::ctor_traits<a2>::type>);

    struct c0{ constexpr explicit(true) c0(empty) { }; };
    static_assert(std::is_same_v<type_list<empty>, di::ctor_traits<c0>::type>);

    struct c1 { c1(int) { } };
    static_assert(std::is_same_v<type_list<int>, di::ctor_traits<c1>::type>);

    struct c2 { c2(const int&) { } };
    static_assert(std::is_same_v<type_list<const int&>, di::ctor_traits<c2>::type>);

    struct c3 { c3(const int&, empty*) { } };
    static_assert(std::is_same_v<type_list<const int&, empty*>, di::ctor_traits<c3>::type>);

    struct c4 { c4(const int&, const empty*, float) { } };
    static_assert(std::is_same_v<type_list<const int&, const empty*, float>, di::ctor_traits<c4>::type>);

    struct c5 { constexpr c5(int, int, int, int) noexcept { } };
    static_assert(std::is_same_v<type_list<int, int, int, int>, di::ctor_traits<c5>::type>);

    struct c6 { constexpr c6(int, int, int, int, int,
                             int, int, int, int, int,
                             int, int, int, int, int) throw() { } };
    static_assert(std::is_same_v<
      type_list<int, int, int, int, int,
                int, int, int, int, int,
                int, int, int, int, int>, di::ctor_traits<c6>::type>);
  }

  // di::invocable
  {
    static_assert(di::invocable<decltype([]{})>);
    static_assert(di::invocable<decltype([](int){})>);
    static_assert(di::invocable<decltype([](const int&){})>);
    static_assert(di::invocable<decltype([]<class... Ts>(Ts...){})>);
    static_assert(di::invocable<decltype([]<auto... >(){})>);
    static_assert(di::invocable<decltype([](auto...){})>);
    static_assert(di::invocable<decltype([](...){})>);
  }

  // di::is
  {
    static_assert(not di::is<int, const int>);
    static_assert(not di::is<int, const int*>);
    static_assert(not di::is<int, const int*>);
    static_assert(di::is<void, void>);
    static_assert(di::is<int, int>);
    static_assert(di::is<const void*, const void*>);
    static_assert(di::is<int&&, int&&>);
  }

  // di::is_a
  {
    static_assert(not di::is_a<int, std::shared_ptr>);
    static_assert(not di::is_a<std::shared_ptr<void>&, std::unique_ptr>);
    static_assert(not di::is_a<const std::shared_ptr<int>&, std::unique_ptr>);
    static_assert(not di::is_a<std::shared_ptr<void>, std::unique_ptr>);
    static_assert(di::is_a<std::shared_ptr<void>, std::shared_ptr>);
    static_assert(di::is_a<std::shared_ptr<int>, std::shared_ptr>);
    static_assert(di::is_a<std::unique_ptr<int>, std::unique_ptr>);
  }

  // di::is_smart_ptr
  {
    static_assert(not di::is_smart_ptr<void>);
    static_assert(not di::is_smart_ptr<void*>);
    static_assert(not di::is_smart_ptr<int>);
    static_assert(not di::is_smart_ptr<const int&>);
    static_assert(not di::is_smart_ptr<const std::shared_ptr<int>&>);
    static_assert(di::is_smart_ptr<std::shared_ptr<void>>);
    static_assert(di::is_smart_ptr<std::shared_ptr<int>>);
    static_assert(di::is_smart_ptr<std::unique_ptr<int>>);
  }

  // di::trait
  {
    static_assert(not di::trait<int, std::is_const>);
    static_assert(di::trait<const int, std::is_const>);
    static_assert(not di::trait<const int&, std::is_pointer>);
    static_assert(di::trait<int*, std::is_pointer>);
    static_assert(not di::trait<int, std::is_class>);
    static_assert(di::trait<std::shared_ptr<void>, std::is_class>);
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

  // di::make
  {
    static_assert(int(42) == di::make<int>(42));
    static_assert(char('x') == di::make<char>('x'));

    struct empty {};
    static_assert(sizeof(di::make<empty>()) == sizeof(empty));

    struct c1 { constexpr c1(int i) : i{i} { } int i{}; };
    static_assert(42 == di::make<c1>(42).i);
    static_assert(42 == di::make<c1>(di::overload{
      [](...) { return 42; }
    }).i);
    static_assert([](auto... ts) { return requires { di::make<c1>(ts...); }; }(int{}));
    static_assert(not [](auto... ts) { return requires { di::make<c1>(ts...); }; }());
    static_assert(not [](auto... ts) { return requires { di::make<c1>(ts...); }; }(float{}));
    static_assert(not [](auto... ts) { return requires { di::make<c1>(ts...); }; }(int{}, int{}));

    struct c2 { constexpr c2(int i, bool b) : i{i}, b{b} { } int i; bool b; };
    static_assert(1 == di::make<c2>(1, true).i);
    static_assert(true == di::make<c2>(1, true).b);
    constexpr auto cfg1 = di::overload{
      [](auto&& t) requires std::is_same_v<typename std::remove_cvref_t<decltype(t)>::value_type, int> { return 42; },
      [](auto&& t) requires std::is_same_v<typename std::remove_cvref_t<decltype(t)>::value_type, bool> { return true; },
    };
    static_assert(42 == di::make<c2>(cfg1).i);
    static_assert(true == di::make<c2>(cfg1).b);

    static_assert([](auto... ts) { return requires { di::make<c2>(ts...); }; }(int{}, bool{}));
    static_assert(not [](auto... ts) { return requires { di::make<c2>(ts...); }; }(bool{}, int{}));
    static_assert(not [](auto... ts) { return requires { di::make<c2>(ts...); }; }(bool{}, char{}));
    static_assert(not [](auto... ts) { return requires { di::make<c2>(ts...); }; }(bool{}, bool{}, bool{}));
  }
}(), true));
#endif // NTEST
