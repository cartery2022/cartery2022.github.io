---
title: Java 11 新特性总结与示例
date: 2025-03-02
tags:
  - java
  - Java11
categories:
  - Java
  - 新版本特性
---

# Java 11 新特性总结与示例

Java 11 于 **2018 年 9 月 25 日** 正式发布，是 **Java 8 之后首个长期支持（LTS）版本**，支持至 2026 年 9 月。本文按语言、API、工具、GC 等分类梳理主要新特性，并配有示例（基于 JDK 11）。

---

## 一、语言层面

### 1.1 Lambda 参数支持 var（JEP 323）

在 Lambda 形参中可以使用 `var`，便于添加注解或统一风格（注意：Java 10 已在局部变量中引入 var，Java 11 扩展到 Lambda 参数）。

```java
import java.util.function.*;

public class VarInLambda {
    public static void main(String[] args) {
        // Lambda 参数可使用 var，便于加注解或统一风格
        BiFunction<Integer, Integer, Integer> add = (var a, var b) -> a + b;
        System.out.println(add.apply(1, 2));  // 3
    }
}
```

### 1.2 嵌套类访问控制（JEP 181）

`Class` 新增 `getNestHost()`、`getNestMembers()` 等方法，嵌套类（内部类等）的访问控制语义更清晰，反射可正确识别“巢”关系。

```java
public class NestDemo {
    class Inner { }
    public static void main(String[] args) {
        Class<?> host = NestDemo.Inner.class.getNestHost();
        System.out.println(host.getName());  // NestDemo
    }
}
```

---

## 二、String 增强

新增方法均针对“空白”和“首尾空格”的现代需求（比 `trim()` 正确处理 Unicode 等）。

| 方法 | 说明 |
|------|------|
| `isBlank()` | 是否为空或仅包含空白字符 |
| `strip()` / `stripLeading()` / `stripTrailing()` | 去除首尾/仅首/仅尾空白 |
| `repeat(int n)` | 将字符串重复 n 次 |
| `lines()` | 按行拆分为 `Stream<String>` |

```java
public class StringDemo {
    public static void main(String[] args) {
        String s = "  hello  ";
        System.out.println(s.isBlank());       // false
        System.out.println("   ".isBlank());   // true
        System.out.println(s.strip());         // "hello"
        System.out.println("ab".repeat(3));    // "ababab"

        "a\nb\nc".lines().forEach(System.out::println);
    }
}
```

---

## 三、集合：不可变工厂

`List`、`Set`、`Map` 提供 `of(...)` 和 `copyOf(...)`，创建不可变集合，避免手写 `Collections.unmodifiableXXX`。

```java
import java.util.*;

public class CollectionDemo {
    public static void main(String[] args) {
        List<String> list = List.of("a", "b", "c");
        Set<Integer> set = Set.of(1, 2, 3);
        Map<String, Integer> map = Map.of("x", 1, "y", 2);
        Map<String, Integer> map2 = Map.ofEntries(
            Map.entry("a", 1),
            Map.entry("b", 2)
        );

        List<String> copy = List.copyOf(list);
        // list.add("d");  // UnsupportedOperationException
        // copy.add("d");  // UnsupportedOperationException
    }
}
```

---

## 四、Stream / Optional 增强

- **Stream**：`ofNullable(T t)`（null 则空流）、`takeWhile`/`dropWhile`、`iterate` 重载（带 Predicate）。
- **Optional**：无新增重要方法（部分文档提到的 `isEmpty()` 在 Java 11 中为 Optional 的增强，实际在后续版本更常见；Optional 在 11 中已有 `isEmpty()` 的讨论，部分实现可能在 11 或 12）。

```java
import java.util.stream.*;

public class StreamDemo {
    public static void main(String[] args) {
        // ofNullable：null 得到空流
        long c = Stream.ofNullable(null).count();
        System.out.println(c);  // 0

        // takeWhile / dropWhile
        Stream.of(1, 2, 3, 4, 5)
            .takeWhile(n -> n < 4)
            .forEach(System.out::print);  // 123
        System.out.println();
        Stream.of(1, 2, 3, 4, 5)
            .dropWhile(n -> n < 4)
            .forEach(System.out::print);  // 45
    }
}
```

---

## 五、HTTP Client 标准化（JEP 321）

从 Java 9 的孵化模块迁至 **`java.net.http`**，支持同步/异步、HTTP/2，可替代 `HttpURLConnection` 或部分第三方 HTTP 库。

```java
import java.net.URI;
import java.net.http.*;
import java.net.http.HttpClient.Version;
import java.time.Duration;

public class HttpClientDemo {
    public static void main(String[] args) throws Exception {
        HttpClient client = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .version(Version.HTTP_2)
            .build();

        HttpRequest request = HttpRequest.newBuilder(URI.create("https://example.com"))
            .timeout(Duration.ofSeconds(5))
            .GET()
            .build();

        // 同步
        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
        System.out.println(response.statusCode());
        System.out.println(response.body().substring(0, Math.min(100, response.body().length())));

        // 异步
        client.sendAsync(request, HttpResponse.BodyHandlers.ofString())
            .thenApply(HttpResponse::body)
            .thenAccept(b -> System.out.println("Async body length: " + b.length()));
    }
}
```

---

## 六、单文件源码运行（JEP 330）

无需先 `javac`，可直接运行单个 `.java` 文件，适合脚本式使用或入门教学。

```bash
# 直接运行
java Hello.java

# 带参数
java --source 11 Main.java arg1 arg2
```

---

## 七、GC 与运行时常量

| 特性 | 说明 |
|------|------|
| **ZGC（JEP 333，实验）** | 可扩展低延迟 GC，目标暂停时间 < 10ms |
| **Epsilon GC（JEP 318）** | 无操作 GC，只分配不回收，用于性能测试等 |
| **动态类文件常量（JEP 309）** | 字节码新增 `CONSTANT_Dynamic` |
| **移除 Java EE / CORBA 模块（JEP 320）** | 正式移除，需要时改用 Jakarta EE 等 |

---

## 八、小结

| 类别 | 特性 | 一句话 |
|------|------|--------|
| 语言 | Lambda 参数 var、嵌套类 | 语法与反射增强 |
| API | String / 集合 / Stream | 不可变集合、String 工具、流式增强 |
| 网络 | HTTP Client | 标准库 HTTP/2 同步与异步 |
| 工具 | 单文件运行 | `java xxx.java` |
| GC/平台 | ZGC、Epsilon、移除 EE | 低延迟 GC、瘦身 JDK |

以上示例均在 JDK 11 下可运行。Java 11 作为 LTS，是许多团队从 8 升级的首选版本。
