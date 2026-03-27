---
title: Java 8 新特性总结与示例
date: 2025-03-02
tags:
  - java
  - Java8
categories:
  - Java
  - 新版本特性
---

# Java 8 新特性总结与示例

Java 8（2014 年 3 月发布）是自 Java 5 以来变化最大的版本，引入了 Lambda、Stream、新日期时间 API 等，奠定了现代 Java 的写法。本文按「语言特性 → 类库 → 其它」梳理所有主要新特性，并配有可运行示例（基于 JDK 8）。

---

## 一、Lambda 表达式与函数式接口

### 1.1 Lambda 表达式

**作用**：把“一段行为”当作参数传递，减少匿名内部类样板代码。

语法形式：`(参数列表) -> 表达式或代码块`。

```java
import java.util.*;
import java.util.function.Consumer;

public class LambdaDemo {
    public static void main(String[] args) {
        List<String> list = Arrays.asList("a", "b", "c");

        // 旧写法：匿名内部类
        list.forEach(new Consumer<String>() {
            @Override
            public void accept(String s) {
                System.out.println(s);
            }
        });

        // Java 8：Lambda
        list.forEach(s -> System.out.println(s));
        list.forEach(System.out::println);  // 方法引用，见下节

        // 多参数、多行
        List<Integer> nums = Arrays.asList(1, 2, 3);
        nums.sort((a, b) -> {
            int diff = a - b;
            return Integer.compare(a, b);
        });
    }
}
```

### 1.2 函数式接口（@FunctionalInterface）

**定义**：有且仅有一个抽象方法的接口，可用 `@FunctionalInterface` 标记，便于编译器检查。

```java
@FunctionalInterface
public interface MyCalculator {
    int compute(int a, int b);
    // 只能有一个抽象方法；default/static 不计入
}

// 使用
MyCalculator add = (a, b) -> a + b;
MyCalculator mul = (a, b) -> a * b;
System.out.println(add.compute(2, 3));  // 5
System.out.println(mul.compute(2, 3));  // 6
```

常见内置函数式接口见第五节。

---

## 二、方法引用与构造器引用

**作用**：当 Lambda 只是“调用已有方法”时，用 `::` 更简洁。

四种形式：静态方法、实例方法（指定对象）、实例方法（任意对象）、构造器。

```java
import java.util.function.*;

public class MethodRefDemo {
    public static void main(String[] args) {
        // 1. 静态方法引用：类::静态方法
        Function<String, Integer> p1 = Integer::parseInt;
        System.out.println(p1.apply("42"));  // 42

        // 2. 实例方法引用（指定对象）：对象::实例方法
        String s = "hello";
        Supplier<Integer> p2 = s::length;
        System.out.println(p2.get());  // 5

        // 3. 实例方法引用（任意对象）：类::实例方法
        BiPredicate<String, String> p3 = String::equals;
        System.out.println(p3.test("a", "a"));  // true

        // 4. 构造器引用：类::new
        Supplier<List<String>> listSupplier = ArrayList::new;
        List<String> list = listSupplier.get();

        Function<Integer, int[]> arrayCreator = int[]::new;
        int[] arr = arrayCreator.apply(10);  // 长度为 10 的 int 数组
    }
}
```

---

## 三、接口的默认方法与静态方法

### 3.1 默认方法（default）

**作用**：在接口里写带实现的方法，实现类不强制重写，便于接口演进而不破坏已有实现。

```java
public interface Vehicle {
    default void start() {
        System.out.println("Vehicle started");
    }
    void run();
}

public class Car implements Vehicle {
    @Override
    public void run() {
        System.out.println("Car running");
    }
    // 可不重写 start()，直接继承默认实现
}
```

### 3.2 静态方法（static）

**作用**：接口也可有静态方法，常用于工具方法。

```java
public interface MathUtil {
    static int add(int a, int b) {
        return a + b;
    }
}

int sum = MathUtil.add(1, 2);  // 3
```

---

## 四、Optional

**作用**：显式表达“可能没有值”，减少 NPE 和散落的 `if (x != null)`。

```java
import java.util.Optional;

public class OptionalDemo {
    public static void main(String[] args) {
        // 创建
        Optional<String> empty = Optional.empty();
        Optional<String> present = Optional.of("hello");
        Optional<String> nullable = Optional.ofNullable(getMaybeNull());

        // 判断与取值
        if (present.isPresent()) {
            System.out.println(present.get());
        }
        present.ifPresent(System.out::println);

        // 默认值
        String v1 = empty.orElse("default");
        String v2 = empty.orElseGet(() -> "computed");

        // 链式转换与过滤
        Optional<String> upper = present.map(String::toUpperCase);
        Optional<String> filtered = present.filter(s -> s.length() > 3);

        // 否则抛异常
        String must = present.orElseThrow(() -> new IllegalStateException("missing"));
    }

    static String getMaybeNull() {
        return Math.random() > 0.5 ? "ok" : null;
    }
}
```

---

## 五、java.util.function 常用函数式接口

| 接口 | 抽象方法 | 典型用途 |
|------|----------|----------|
| `Predicate<T>` | `boolean test(T t)` | 过滤、判断 |
| `Function<T,R>` | `R apply(T t)` | 转换、映射 |
| `Consumer<T>` | `void accept(T t)` | 消费、副作用 |
| `Supplier<T>` | `T get()` | 无参生成值 |
| `UnaryOperator<T>` | `T apply(T t)` | 一元运算 |
| `BiFunction<T,U,R>` | `R apply(T t, U u)` | 二元函数 |

```java
Predicate<Integer> even = n -> n % 2 == 0;
Function<String, Integer> len = String::length;
Consumer<String> print = System.out::println;
Supplier<Double> random = Math::random;

System.out.println(even.test(4));       // true
System.out.println(len.apply("abc"));   // 3
print.accept("hi");
System.out.println(random.get());
```

---

## 六、Stream API

**作用**：对集合做声明式“流式”操作（过滤、映射、排序、归约等），支持顺序与并行。

### 6.1 创建流

```java
import java.util.*;
import java.util.stream.*;

List<String> list = Arrays.asList("a", "b", "c");
Stream<String> s1 = list.stream();
Stream<String> s2 = list.parallelStream();
Stream<String> s3 = Stream.of("x", "y");
Stream<Integer> s4 = Stream.iterate(0, n -> n + 1).limit(5);  // 0,1,2,3,4
Stream<Double> s5 = Stream.generate(Math::random).limit(3);
```

### 6.2 中间操作与终止操作

```java
// 过滤、映射、排序、去重、跳过、限制
List<Integer> nums = Arrays.asList(3, 1, 4, 1, 5, 9, 2, 6);

List<Integer> result = nums.stream()
    .filter(n -> n > 2)
    .map(n -> n * 2)
    .distinct()
    .sorted()
    .skip(1)
    .limit(3)
    .collect(Collectors.toList());
// 结果依赖顺序，此处示例为 [8, 10, 12] 一类
```

### 6.3 常用终止操作

```java
long count = nums.stream().count();
Optional<Integer> max = nums.stream().max(Integer::compareTo);
Optional<Integer> min = nums.stream().min(Integer::compareTo);
boolean any = nums.stream().anyMatch(n -> n > 5);
boolean all = nums.stream().allMatch(n -> n > 0);
Optional<Integer> first = nums.stream().findFirst();

int sum = nums.stream().mapToInt(Integer::intValue).sum();
Optional<Integer> reduce = nums.stream().reduce((a, b) -> a + b);
```

### 6.4 收集器 Collectors

```java
List<String> names = Arrays.asList("Alice", "Bob", "Charlie");
String joined = names.stream().collect(Collectors.joining(", "));
Map<Integer, List<String>> byLen = names.stream()
    .collect(Collectors.groupingBy(String::length));
Map<Boolean, List<String>> partition = names.stream()
    .collect(Collectors.partitioningBy(s -> s.length() > 4));
```

---

## 七、新的日期时间 API（java.time）

**作用**：替代易错的 `Date`/`Calendar`，提供不可变、线程安全的日期时间类型。

```java
import java.time.*;
import java.time.format.DateTimeFormatter;

// 本地日期、时间、日期时间
LocalDate date = LocalDate.now();
LocalDate date2 = LocalDate.of(2025, 3, 2);
LocalTime time = LocalTime.of(14, 30);
LocalDateTime dateTime = LocalDateTime.of(date2, time);

// 解析与格式化
DateTimeFormatter fmt = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");
String str = dateTime.format(fmt);
LocalDateTime parsed = LocalDateTime.parse("2025-03-02 14:30", fmt);

// 加减
LocalDate tomorrow = date.plusDays(1);
LocalDateTime before = dateTime.minusHours(2);

// 带时区
ZonedDateTime zoned = ZonedDateTime.now(ZoneId.of("Asia/Shanghai"));
Instant instant = Instant.now();
```

---

## 八、重复注解与类型注解

### 8.1 重复注解（Repeating Annotations）

**作用**：同一注解可在同一位置多次使用，内部用“容器注解”保存。

```java
import java.lang.annotation.*;

@Repeatable(Roles.class)
@Retention(RetentionPolicy.RUNTIME)
@interface Role {
    String value();
}

@Retention(RetentionPolicy.RUNTIME)
@interface Roles {
    Role[] value();
}

@Role("admin")
@Role("user")
class User { }
```

### 8.2 类型注解（Type Annotations）

**作用**：注解可写在类型使用处（如泛型、类型转换），用于更强类型检查或工具分析。

```java
// 需配合 Checker Framework 等使用，此处仅展示语法位置
// List<@NonNull String> list;
// String s = (@NonNull String) obj;
```

---

## 九、Base64 编码解码

**作用**：标准库内置 Base64，无需第三方库。

```java
import java.util.Base64;

String text = "Hello, Java 8!";
String encoded = Base64.getEncoder().encodeToString(text.getBytes());
System.out.println(encoded);

byte[] decoded = Base64.getDecoder().decode(encoded);
System.out.println(new String(decoded));

// URL 安全、MIME 等变体：Base64.getUrlEncoder() / getMimeEncoder()
```

---

## 十、Nashorn JavaScript 引擎

**作用**：在 JVM 内执行 JavaScript（Java 15+ 已移除，仅作历史特性了解）。

```java
import javax.script.*;

ScriptEngine engine = new ScriptEngineManager().getEngineByName("nashorn");
engine.eval("var greeting = 'Hello from JS'; greeting");
Object result = engine.eval("1 + 2");
System.out.println(result);  // 3.0

// 调用 JS 函数
engine.eval("function add(a, b) { return a + b; }");
Invocable invocable = (Invocable) engine;
Object sum = invocable.invokeFunction("add", 10, 20);
System.out.println(sum);  // 30.0
```

---

## 十一、其它改进

- **并行数组排序**：`Arrays.parallelSort(...)` 大数组排序时可利用多核。
- **HashMap 冲突优化**：桶内链表过长时转为红黑树，减少极端情况下的性能退化。
- **Compact Profiles**：Java SE 8 提供 compact1/2/3 子集，便于小型设备。
- **参数名反射**：通过 `Parameter` 可获取方法参数名（需编译时加 `-parameters`）。

---

## 十二、小结

| 类别 | 特性 | 一句话 |
|------|------|--------|
| 语言 | Lambda | 把行为当参数，简化匿名类 |
| 语言 | 方法/构造器引用 | `::` 简化“只调一个方法”的 Lambda |
| 语言 | 接口 default/static | 接口可带实现，便于演进 |
| 语言 | 重复/类型注解 | 多次注解、类型上的注解 |
| 类库 | Optional | 显式“可能无值”，减少 NPE |
| 类库 | Stream API | 声明式集合操作，支持并行 |
| 类库 | java.util.function | 常用函数式接口 |
| 类库 | java.time | 新日期时间 API |
| 类库 | Base64 | 内置编码解码 |
| 其它 | Nashorn、并行排序、HashMap 等 | 脚本、性能与平台优化 |

以上示例均在 JDK 8 下可运行（Nashorn 在 JDK 15+ 需单独依赖或改用 GraalJS）。掌握这些特性即可覆盖日常开发中绝大部分 Java 8 用法。
