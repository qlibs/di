template<class...> struct q;
#include <di>
//#include <boost/mp11.hpp>
//#include <reflect>
#include <iostream>
#include <vector>
#include <concepts>
#include <memory>
#include <typeinfo>

struct bar {
  bar(int i1, int& i2, const int& i3, int/*&&*/ i4) : i1(i1), i2(i2), i3(i3), i4(static_cast<int&&>(i4)) { }
  int i1;
  int& i2;
  const int& i3;
  int i4;
};

struct interface {
  virtual int foo() = 0;
  virtual ~interface() = default;
};

struct implementation : interface {
  implementation(std::shared_ptr<int> i) :i{i} {}
  int foo() override final { return *i; }
  std::shared_ptr<int> i{};
};

struct baz {
  baz(interface* i_, std::shared_ptr<int> i) : i_(i_), i(i) {
    std::cout << typeid(i_).name() << " " << i_->foo() << std::endl;
    std::cout << typeid(i).name() << std::endl;
  }
  baz(const baz&) = delete;
  baz(baz&&) = default;
  ~baz() {
    if (i) delete i_;
    i_ = nullptr;
  }
  interface* i_;
  std::shared_ptr<int> i;
};

struct foo {
  //foo(bar b, int i1, int i2, baz z, std::shared_ptr<int> i) : b{b}, i1{i1}, i2{i2}, z{z}, i{i} { }
  bar br;
  baz b;
  int i1;
  int i2;
  //baz z;
  double& f;
  //std::shared_ptr<int> i;
};

template<class T, template<class> class Trait> concept trait = Trait<T>::value;
template<class T, template<class> class R> concept is_a = std::same_as<R<typename T::element_type>, T>;

inline constexpr auto make = []<class T>(auto&&... args) { return T(std::forward<decltype(args)>(args)...); };
inline constexpr auto make_ptr = []<class T>(auto&&... args) { return new T(std::forward<decltype(args)>(args)...); };
inline constexpr auto make_shared_ptr = []<class T>(auto&&... args) { return std::make_shared<T>(std::forward<decltype(args)>(args)...); };

template<class T> inline std::remove_cvref_t<T> singleton{};
template<class If, class Impl> inline constexpr auto bind = []<std::same_as<If>, class... Ts>(auto&& t, auto&& fn) { return di::apply<Impl, Ts...>(t, fn); };
template<class T> inline constexpr auto let = [](auto&& fn) { return [fn]<std::same_as<T>, class... Ts>(auto&&) { return fn(); }; };

constexpr auto injection = di::utility::overload{
  []<trait<std::is_pointer> T, class... Ts>(auto&& t) { return t.template operator()<std::remove_cvref_t<std::remove_pointer_t<T>>, Ts...>(t, make_ptr); },
  []<is_a<std::shared_ptr> T, class... Ts>(auto&& t) { return t.template operator()<typename T::element_type>(t, make_shared_ptr); },
  []<trait<std::is_reference> T, class... Ts>(auto&& t) -> decltype(auto) {
    if (not singleton<T>) singleton<T> = t.template operator()<std::remove_cvref_t<T>, Ts...>(t, make);
    return static_cast<T>(singleton<T>);
  },
  []<class T, class... Ts>(auto&& t) { return t.template operator()<T, Ts...>(t, make); },
  []<class T, class... Ts>(auto&& t, auto&& fn) { return di::apply<T, Ts...>(t, fn); },
};

int main() {
  constexpr auto injector =
    di::utility::overload{
      let<int>([] { return 42; }),
      let<double>([] { return 4.2; }),
      bind<interface, implementation>,
      injection,
    };

  auto f = di::create<foo>(injector);

  std::cout << f.i1 << std::endl;
  std::cout << f.i2 << std::endl;
}
