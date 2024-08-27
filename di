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
[![Try it online](https://img.shields.io/badge/try%20it-online-blue.svg)](https://godbolt.org/z/xrzsYG1bj)

  > https://en.wikipedia.org/wiki/Dependency_injection (for additional info see [FAQ](#faq))

### Features

- Single header (https://raw.githubusercontent.com/qlibs/di/main/di - for integration see [FAQ](#faq))
- Verifies itself upon include (can be disabled with `-DNTEST` - see [FAQ](#faq))
- Minimal [API](#api)
  - Unified way for different polymorphism styles (`inheritance, type_erasure, variant, ...`)
    - [Generic factories](https://en.wikipedia.org/wiki/Factory_method_pattern)
  - Constructor deduction for classes and aggregates
  - Constructor order and types changes agnostic (simplifies integration with `third party` libraries)
  - Testing (different bindigns for `production` and `testing`, `faking` some parameters with `assisted` injection)
  - Policies (APIs with `checked` requirements)
  - Logging/Profiling/Serialization/... (via iteration over all `created` objects)

### Requirements

- C++20 ([clang++13+, g++11+](https://en.cppreference.com/w/cpp/compiler_support))

---

### Overview

> API (https://godbolt.org/z/xrzsYG1bj)

```cpp
struct aggregate1 { int i1{}; int i2{}; };
struct aggregate2 { int i2{}; int i1{}; };
struct aggregate  { aggregate1 a1{}; aggregate2 a2{}; };

// di::make (basic)
{
  static_assert(42 == di::make<int>(42));
  static_assert(aggregate1{1, 2} == di::make<aggregate1>(1, 2));
}

// di::make (generic)
{
  auto a = di::make<aggregate1>(di::overload{
    [](di::trait<std::is_integral> auto) { return 42; }
  });

  assert(a.i1 == 42);
  assert(a.i2 == 42);
}

// di::make (assisted)
{
  struct assisted {
    constexpr assisted(int i, aggregate a, float f) : i{i}, a{a}, f{f} { }
    int i{};
    aggregate a{};
    float f{};
  };

  auto fakeit = [](auto t) { return decltype(t.type()){}; };
  auto a = di::make<assisted>(999, di::make<aggregate>(fakeit), 4.2f);

  assert(a.i == 999);
  assert(a.a.a1.i1 == 0);
  assert(a.a.a1.i2 == 0);
  assert(a.a.a2.i1 == 0);
  assert(a.a.a2.i2 == 0);
  assert(a.f == 4.2f);
}

// di::make (with names)
{
  auto a = di::make<aggregate1>(di::overload{
    [](di::is<int> auto t) requires (t.name() == "i1") { return 4; },
    [](di::is<int> auto t) requires (t.name() == "i2") { return 2; },
  });

  assert(a.i1 == 4);
  assert(a.i2 == 2);
}

// di::make (with names) - reverse order
{
  auto a = di::make<aggregate2>(di::overload{
    [](di::is<int> auto t) requires (t.name() == "i1") { return 4; },
    [](di::is<int> auto t) requires (t.name() == "i2") { return 2; },
  });

  assert(a.i1 == 4);
  assert(a.i2 == 2);
}

// di::make (with names, context and compound types)
{
  auto a = di::make<aggregate>(di::overload{
    // custom bindigs
    [](di::trait<std::is_integral> auto t)
      requires (t.name() == "i1" and
                &typeid(t.parent().type()) == &typeid(aggregate1)) { return 99; },
    [](di::trait<std::is_integral> auto) { return 42; },

    // generic bindings
    [](auto t) -> decltype(auto) { return di::make(t); }, // compund types
  });

  assert(a.a1.i1 == 99);
  assert(a.a1.i2 == 42);
  assert(a.a2.i1 == 42);
  assert(a.a2.i2 == 42);
}

constexpr auto generic = di::overload{
  [](auto t) -> decltype(auto) { return di::make(t); }, // compund types
};

// di::make (seperate overloads)
{
  constexpr auto custom = di::overload {
    [](di::trait<std::is_integral> auto t)
      requires (t.name() == "i1" and
                &typeid(t.parent().type()) == &typeid(aggregate1)) { return 99; },
    [](di::trait<std::is_integral> auto t) { return decltype(t.type()){}; },
  };

  auto a = di::make<aggregate>(di::overload{custom, generic});

  assert(a.a1.i1 == 99);
  assert(a.a1.i2 == 0);
  assert(a.a2.i1 == 0);
  assert(a.a2.i2 == 0);
}

// di::make (polymorphism, scopes)
{
  struct interface {
    constexpr virtual ~interface() noexcept = default;
    constexpr virtual auto fn() const -> int = 0;
  };
  struct implementation : interface {
    constexpr implementation(int i) : i{i} { }
    constexpr auto fn() const -> int override final { return i; }
    int i{};
  };

  struct example {
    example(
      aggregate& a,
      const std::shared_ptr<interface>& sp
    ) : a{a}, sp{sp} { }
    aggregate a{};
    std::shared_ptr<interface> sp{};
  };

  auto i = 123;

  auto bindings = di::overload{
    generic,

    [](di::is<interface> auto t) { return di::make<implementation>(t); },
    [&](di::is<int> auto) -> decltype(auto) { return i; }, // instance

    // scopes
    [](di::trait<std::is_reference> auto t) -> decltype(auto) {
      using type = decltype(t.type());
      static auto singleton{di::make<std::remove_cvref_t<type>>(t)};
      return (singleton);
    },
  };

  auto e = di::make<example>(bindings);

  assert(123 == e.sp->fn());
  assert(123 == e.a.a1.i1);
  assert(123 == e.a.a1.i2);
  assert(123 == e.a.a2.i1);
  assert(123 == e.a.a2.i2);

  // testing (override bindings)
  {
    auto testing = di::overload{
      [](di::trait<std::is_integral> auto) { return 1000; }, // priority
      [bindings](auto t) -> decltype(auto) { return bindings(t); }, // otherwise
    };

    auto e = di::make<example>(testing);

    assert(1000 == e.sp->fn());
    assert(1000 == e.a.a1.i1);
    assert(1000 == e.a.a1.i2);
    assert(1000 == e.a.a2.i1);
    assert(1000 == e.a.a2.i2);
  }

  // logging
  {
    constexpr auto logger = [root = false]<class T, class TIndex, class TParent>(
        di::provider<T, TIndex, TParent>&& t) mutable -> decltype(auto) {
      if constexpr (constexpr auto is_root =
          di::provider<T, TIndex, TParent>::size() == 1u; is_root) {
        if (not std::exchange(root, true)) {
          std::clog << reflect::type_name<decltype(t.parent().type())>() << '\n';
        }
      }
      for (auto i = 0u; i < di::provider<T, TIndex, TParent>::size(); ++i) {
        std::clog << ' ';
      }
      if constexpr (di::is_smart_ptr<std::remove_cvref_t<T>>) {
        std::clog << reflect::type_name<T>() << '<'
                  << reflect::type_name<
                      typename std::remove_cvref_t<T>::element_type>() << '>';
      } else {
        std::clog << reflect::type_name<T>();
      }
      if constexpr (not di::is_smart_ptr<std::remove_cvref_t<T>> and
        requires { std::clog << std::declval<T>(); }) {
        std::clog << ':' << t(t);
      }
      std::clog << '\n';

      return t(t);
    };

    (void)di::make<example>(di::overload{logger, bindings});
    // example
    //  aggregate
    //   aggregate1
    //    int:123
    //    int:123
    //   aggregate2
    //    int:123
    //    int:123
    //  shared_ptr<interface> -> implmentation
    //    int:123
  }
}

// policies
{
  struct policy {
    constexpr policy(int*) { }
  };

  [[maybe_unused]] auto p = di::make<policy>(di::overload{
    []([[maybe_unused]] di::trait<std::is_pointer> auto t) {
      static_assert(not sizeof(t), "raw pointers are not allowed!");
    },
    [](auto t) -> decltype(auto) { return di::make(t); }, // compund types
  }); // error
}

// errors
{
  (void)di::make<aggregate1>(di::overload{
    // [](di::is<int> auto) { return 42; }, // missing binding
    [](auto t) { return di::make(t); },
  }); // di::error<int, ...>
}

// and more (see API)...
```

---

### Examples

> DIY - Dependency Injection Yourself (https://godbolt.org/z/acE3rYar5)

```cpp
namespace di {
inline constexpr auto injector = [](auto&&... ts) {
  return di::overload{
    std::forward<decltype(ts)>(ts)...,
    [](di::trait<std::is_reference> auto t) -> decltype(auto) {
      using type = decltype(t.type());
      static auto singleton{di::make<std::remove_cvref_t<type>>(t)};
      return (singleton);
    },
    [](auto t) { return di::make(t); },
  };
};
template<class T, class R = void>
inline constexpr auto bind = [] {
  if constexpr (std::is_void_v<R>) {
    return [](T&& to) {
      return [&](di::is<T> auto) -> decltype(auto) {
        return std::forward<T>(to);
      };
    };
  } else {
    return [](di::is<T> auto t) { return di::make<R>(t); };
  }
}();
} // namespace di
```

```cpp
int main() {
  auto injector = di::injector(
    di::bind<interface, implementation>,
    di::bind<int>(42)
  );

  auto e = di::make<example>(injector);

  assert(42 == e.sp->fn());
  assert(42 == e.a.a1.i1);
  assert(42 == e.a.a1.i2);
  assert(42 == e.a.a2.i1);
  assert(42 == e.a.a2.i2);
}
```

> Standard Template Library (https://godbolt.org/z/jjbnffKne)

```cpp
struct STL {
  STL(std::vector<int> vector,
      std::shared_ptr<void> shared_ptr,
      std::unique_ptr<int> unique_ptr,
      std::array<int, 42> array,
      std::string string)
    : vector(vector)
    , shared_ptr(shared_ptr)
    , unique_ptr(std::move(unique_ptr))
    , array(array)
    , string(string)
  { }

  std::vector<int> vector;
  std::shared_ptr<void> shared_ptr;
  std::unique_ptr<int> unique_ptr;
  std::array<int, 42> array;
  std::string string;
};

int main() {
  auto stl = di::make<STL>(
    di::overload{
      [](di::is<std::vector<int>> auto) { return std::vector{1, 2, 3}; },
      [](di::is<std::shared_ptr<void>> auto) { return std::make_shared<int>(1); },
      [](di::is<std::unique_ptr<int>> auto) { return std::make_unique<int>(2); },
      [](di::is<std::array<int, 42>> auto) { return std::array<int, 42>{3}; },
      [](di::is<std::string> auto) { return std::string{"di"}; },
      [](auto t) { return di::make(t); },
    }
  );

  assert(3u == stl.vector.size());
  assert(1 == stl.vector[0]);
  assert(2 == stl.vector[1]);
  assert(3 == stl.vector[2]);
  assert(1 == *static_cast<const int*>(stl.shared_ptr.get()));
  assert(2 == *stl.unique_ptr);
  assert(3 == stl.array[0]);
  assert("di" == stl.string);
}
```

> `is_structural` - https://eel.is/c++draft/temp.param#def:type,structural (https://godbolt.org/z/1Mrxfbaqb)

```cpp
template<class T, auto cfg =
  [](auto t) {
    using type = std::remove_cvref_t<decltype(t.type())>;
    if constexpr (requires { type{}; }) {
      return type{};
    } else {
      return di::make(t);
    }
  }
> concept is_structural = requires { []<T = di::make<T>(cfg)>{}(); };

static_assert(is_structural<int>);
static_assert(not is_structural<std::optional<int>>);

struct s { s() = delete; };
static_assert(not is_structural<s>);

struct y { int i; };
static_assert(is_structural<y>);

struct n { private: int i; };
static_assert(not is_structural<n>);

struct c1 { constexpr c1(int) {} };
static_assert(is_structural<c1>);

struct c2 { constexpr c2(int, double) {} };
static_assert(is_structural<c2>);

struct c3 { constexpr c3(std::optional<int>) {} };
static_assert(not is_structural<c3>);

struct c4 { constexpr c4(auto...) {} };
static_assert(is_structural<c4>);

struct c5 { private: constexpr c5(auto...) {} };
static_assert(not is_structural<c5>);
```

----

### API

```cpp
namespace di::inline v1_0_5 {
/**
 * @code
 * struct c1 { c1(int) { } };
 * static_assert(std::is_same_v<type_list<int>, di::ctor_traits<c1>::type>);
 * #endcode
 */
template<class T, std::size_t N = 16u> struct ctor_traits {
  template<class...> struct type_list{};
  using type = type_list</* T constructor parameters (size = N..0)`)*/>;
  [[nodiscard]] constexpr auto operator()(auto&&...) const -> T;
};

/**
 * static_assert(di::invocable<decltype([]{})>);
 * static_assert(di::invocable<decltype([](auto...){})>);
 */
template<class T> concept invocable;

/**
 * @code
 * static_assert(not di::is<int, const int>);
 * static_assert(di::is<void, void>);
 * @endcode
 */
template<class TLhs, class TRhs> concept is;

/**
 * @code
 * static_assert(not di::is_a<int, std::shared_ptr>);
 * static_assert(di::is_a<std::shared_ptr<void>, std::shared_ptr>);
 */
template<class T, template<class...> class R> concept is_a;

/**
 * @code
 * static_assert(not di::is_smart_ptr<void>);
 * static_assert(di::is_smart_ptr<std::unique_ptr<int>>);
 */
template<class T> concept is_smart_ptr;

/**
 * @code
 * static_assert(not di::trait<int, std::is_const>);
 * static_assert(di::trait<const int, std::is_const>);
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

  static constexpr auto index()  -> std::size_t;      // index of parent constructor
  static constexpr auto parent() -> parent_type;      // callee provider
  static constexpr auto type()   -> value_type;       // underlying type
  static constexpr auto size()   -> std::size_t;      // size of parents
  #if defined(REFLECT)
  static constexpr auto name()   -> std::string_view; // member name
  #endif
};

/**
 * @code
 * static_assert(42 == di::make<int>(42));
 * static_assert(42 == di::make<int>(
 *   di::overload{
 *     [](di::is<int> auto) { return 42; }
 *   }
 * ));
 * @endcode
 */
template<class T>
[[nodiscard]] constexpr auto make(auto&&...);
} // namespace di
```

---

### FAQ

- Dependency Injection?

  > Dependency Injection (DI) - https://en.wikipedia.org/wiki/Dependency_injection - it's a technique focusing on producing loosely coupled code.

    ```cpp
    struct no_di {
      constexpr no_di() { } // No DI

     private:
      int data = 42; // coupled
    };

    struct di {
      constexpr di(int data) : data{data} { } // DI

     private:
       int data{};
    };
    ```

    - In a very simplistic view, DI is about passing objects/types/etc via constructors and/or other forms of parameter propagating techniques instead of coupling values/types directly - `Hollywood Principle - Don't call us we'll call you`.
    - The main goal of DI is the flexibility of changing what's being injected. It's important though, what and how is being injected as that influences how good (`ETC - Easy To Change`) the design will be - more about it here - https://www.youtube.com/watch?v=yVogS4NbL6U.

- Manual vs Automatic Dependency Injection?

  > Depedency Injection doesnt imply using a library.
    Automatic DI requires a library and makes more sense for larger projects as it helps limitting the wiring mess and the maintenance burden assosiated with it.

    ```cpp
    struct coffee_maker {
      coffee_maker(); // No DI

     private:
      basic_heater heater{};
      basic_pump pump{};
    };

    struct coffee_maker_v1 {
      coffee_maker(iheater&, ipump& pump); // DI

     private:
      iheater& heater;
      ipump& pump;
    };

    struct coffee_maker_v2 {
      coffee_maker(std::shared_ptr<ipump>, std::unique_ptr<iheater>); // DI

     private:
      std::shared_ptr<ipump> pump;
      std::unique_ptr<iheater> heater;
    };

    int main() {
      // Manual Dependency Injection
      {
        basic_heater heater{};
        basic_pump pump{};
        coffe_maker_v1 cm{heater, pump};
      }
      {
        auto pump = std::make_shared<basic_pump>();
        auto heater = std::make_unique<basic_heater>();
        coffe_maker_v2 cm{pump, std::move(heater)}; // different wiring
      }

      // Automatic Dependency Injection
      auto wiring = di::overload{
        [](di::is<iheater> auto) { return make<basic_heater>(); },
        [](di::is<ipump> auto)   { return make<basic_pump>(); },
      };
      {
        auto cm = di::make<coffee_maker_v1>(wiring);
      }
      {
        auto cm = di::make<coffee_maker_v2>(wiring); // same wiring
      }
    }
    ```

- How does it work?

  > `DI` works by deducing constructor parameters and calling appropriate overload to handle them by leavaring concepts - https://eel.is/c++draft/temp.constr.order#def:constraint,subsumption.
    The following represents the most important parts of the library design.

    ```cpp
    template<class B, class T>
    concept copy_or_move = std::is_same_v<B, std::remove_cvref_t<T>>;

    template<class B, std::size_t N> struct any {
      template<class T> requires (not copy_or_move<B, T>)
        operator T() noexcept(noexcept(bind<arg<B, N>, T>{}));
      template<class T> requires (not copy_or_move<B, T>)
        operator T&() const noexcept(noexcept(bind<arg<B, N>, T&>{}));
      template<class T> requires (not copy_or_move<B, T>)
        operator const T&() const noexcept(noexcept(bind<arg<B, N>, const T&>{}));
      template<class T> requires (not copy_or_move<B, T>)
        operator T&&() const noexcept(noexcept(bind<arg<B, N>, T&&>{}));
    };
    ```

    ```cpp
    template<class T, std::size_t N = 16u> constexpr auto ctor_traits() {
      return []<std::size_t... Ns>(std::index_sequence<Ns...>) {
        if constexpr (requires { T{any<T, Ns>{}...}; }) {
          return type_list<typename decltype(get(detail::arg<T, Ns>{}))::value_type...>{};
        } else if constexpr (sizeof...(Ns)) {
          return ctor_traits<T, N - 1u>();
        } else {
          return type_list{};
        }
      }(std::make_index_sequence<N>{});
    }
    ```

    ```cpp
    template<class... Ts> struct overload : Ts... { using Ts::operator()...; };
    template<class... Ts> overload(Ts...) -> overload<Ts...>;
    ```

    ```cpp
    template<class T, class...> auto error(auto&&...) -> T;
    template<class T> constexpr auto make(invocable auto&& t) {
      return [&]<template<class...> class TList, class... Ts>(TList<Ts...>) {
        if constexpr (requires { T{t(provider<Ts>(t)...); }; }) {
          return T{t(provider<Ts>(t)...};
        } else {
          return error<T>(t);
        }
      }(ctor_traits<T>());
    };
    ```

- How to disable running tests at compile-time?

    > When `-DNTEST` is defined static_asserts tests wont be executed upon include.
    Note: Use with caution as disabling tests means that there are no gurantees upon include that given compiler/env combination works as expected.

- How to integrate with [CMake.FetchContent](https://cmake.org/cmake/help/latest/module/FetchContent.html)?

    ```
    include(FetchContent)

    FetchContent_Declare(
      qlibs.di
      GIT_REPOSITORY https://github.com/qlibs/di
      GIT_TAG v1.0.5
    )

    FetchContent_MakeAvailable(qlibs.di)
    ```

    ```
    target_link_libraries(${PROJECT_NAME} PUBLIC qlibs.di);
    ```

- Acknowledgments
  > - ["Dependency Injection - a 25-dollar term for a 5-cent concept"](https://www.youtube.com/watch?v=yVogS4NbL6U) (video)
  > - ["Law of Demeter: A Practical Guide to Loose Coupling"](https://www.youtube.com/watch?v=QZkVpZlbM4U) (video)
  > - ["Clean Code: A Handbook of Agile Software Craftsmanship"](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882) (book)
  > - ["The Pragmatic Programmer"](https://www.amazon.com/Pragmatic-Programmer-journey-mastery-Anniversary/dp/0135957052/ref=pd_sbs_d_sccl_3_1/140-7224166-5387863?pd_rd_w=muV95&content-id=amzn1.sym.156274ff-6322-443d-8bbf-ab3ed87e382f&pf_rd_p=156274ff-6322-443d-8bbf-ab3ed87e382f&pf_rd_r=ECRZDQ02XA134FQJJQDE&pd_rd_wg=ELPtc&pd_rd_r=49d9e9b3-a8b1-4532-b3b3-16711496a3d3&pd_rd_i=0135957052&psc=1) (book)
  > - ["Design Patterns"](https://www.amazon.com/Design-Patterns-Object-Oriented-Addison-Wesley-Professional-ebook/dp/B000SEIBB8) (book)
  > - ["Test Driven Development: By Example"](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530) (book)

- Similar projects?
  > [boost-ext.di](https://github.com/boost-ext/di), [google.fruit](https://github.com/google/fruit)

<!--
#endif

#pragma once
#pragma GCC system_header

#include <cstdint>
#include <utility>
#include <type_traits>
#include <memory>

namespace di::inline v1_0_5 {
namespace detail {
template<class... Ts> struct type_list {
  static constexpr auto size() { return sizeof...(Ts); }
};
template<class T> struct provider { using value_type = T; };
template<class, std::size_t> struct arg { friend constexpr auto get(arg); };
template<class B, class T> struct bind { friend constexpr auto get(B) { return provider<T>{}; } };
template<class B, class T> concept copy_or_move = std::is_same_v<B, std::remove_cvref_t<T>>;
template<class B, std::size_t N> struct any {
  template<class T> requires (not copy_or_move<B, T>) operator T() noexcept(noexcept(bind<arg<B, N>, T>{}));
  template<class T> requires (not copy_or_move<B, T>) operator T&() const noexcept(noexcept(bind<arg<B, N>, T&>{}));
  template<class T> requires (not copy_or_move<B, T>) operator const T&() const noexcept(noexcept(bind<arg<B, N>, const T&>{}));
  template<class T> requires (not copy_or_move<B, T>) operator T&&() const noexcept(noexcept(bind<arg<B, N>, T&&>{}));
};
} // namespace detail
template<class T, std::size_t N = 16u> struct ctor_traits {
  using type = detail::type_list<>;
  [[nodiscard]] constexpr auto operator()() const -> T {
    return T{};
  }
  static constexpr auto size() { return type::size(); }
};
template<class T, std::size_t N> requires (not std::is_class_v<T> and requires(T t) { T{t}; })
struct ctor_traits<T, N> {
  using type = detail::type_list<T>;
  template<class... Ts> [[nodiscard]] constexpr auto operator()(Ts&&... ts) const -> T
    requires requires { T{std::forward<Ts>(ts)...}; } {
    return T{std::forward<Ts>(ts)...};
  }
  static constexpr auto size() { return type::size(); }
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
  static constexpr auto size() { return type::size(); }
};
template<class T, std::size_t N>
struct ctor_traits<std::shared_ptr<T>, N> {
  using type = detail::type_list<T>;
  [[nodiscard]] constexpr auto operator()(auto&& t) const -> std::shared_ptr<T>
    requires requires { std::make_shared<std::remove_cvref_t<decltype(t)>>(std::forward<decltype(t)>(t)); } {
    return std::make_shared<std::remove_cvref_t<decltype(t)>>(std::forward<decltype(t)>(t));
  }
  static constexpr auto size() { return type::size(); }
};
template<class T, std::size_t N>
struct ctor_traits<std::unique_ptr<T>, N> {
  using type = detail::type_list<T>;
  [[nodiscard]] constexpr auto operator()(auto&& t) const -> std::shared_ptr<T>
    requires requires { std::make_unique<std::remove_cvref_t<decltype(t)>>(std::forward<decltype(t)>(t)); } {
    return std::make_unique<std::remove_cvref_t<decltype(t)>>(std::forward<decltype(t)>(t));
  }
  static constexpr auto size() { return type::size(); }
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
  auto&& t = [&]() -> decltype(auto) {
    if constexpr (not requires { typename std::remove_cvref_t<T>::parent_type; }) {
      return provider<R, std::integral_constant<std::size_t, 0u>, std::remove_cvref_t<T>>{std::forward<T>(t_)};
    } else {
      return std::forward<T>(t_);
    }
  }();
  const auto make = [&]<template<class...> class TList, class... Ts>(TList<Ts...>) -> decltype(auto) {
    return [&]<std::size_t... Ns>(std::index_sequence<Ns...>) -> decltype(auto) {
      if constexpr (requires { ctor_traits<R>{}(t(provider<Ts, std::integral_constant<std::size_t, Ns>, std::remove_cvref_t<decltype(t)>>{std::forward<decltype(t)>(t)})...); }) {
        return ctor_traits<R>{}(
          t(provider<Ts, std::integral_constant<std::size_t, Ns>, std::remove_cvref_t<decltype(t)>>{std::forward<decltype(t)>(t)})...
        );
      } else {
        return error<R>(t);
      }
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
[[nodiscard]] constexpr auto make(auto&& t)
  -> decltype(di::make<typename std::remove_cvref_t<decltype(t)>::value_type>(t)) {
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
