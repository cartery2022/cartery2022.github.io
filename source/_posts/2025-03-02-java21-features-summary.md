---
title: Java 21 新特性总结与示例
date: 2025-03-02
tags:
  - java
  - Java21
categories:
  - Java
  - 新版本特性
---

# Java 21 新特性总结与示例

Java 21 于 **2023 年 9 月 19 日** 正式发布，是 **当前最新的 LTS（长期支持）版本**，支持至 2031 年 9 月。本文按语言、API、并发、GC 等分类梳理主要新特性，并配有示例（基于 JDK 21）。

---

## 一、虚拟线程（Virtual Threads，JEP 444）

**作用**：由 JVM 管理的轻量级线程，用少量 OS 线程承载大量虚拟线程，适合“一请求一线程”的高吞吐场景，无需改业务逻辑，只需改变线程创建方式。

```java
import java.util.concurrent.*;
import java.util.stream.IntStream;

public class VirtualThreadDemo {
    public static void main(String[] args) throws Exception {
        // 创建虚拟线程
        Thread vt = Thread.ofVirtual().start(() -> System.out.println("Virtual: " + Thread.currentThread()));

        try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
            IntStream.range(0, 5).forEach(i ->
                executor.submit(() -> {
                    System.out.println(Thread.currentThread() + " -> " + i);
                    return i;
                })
            );
        }

        vt.join();
    }
}
```

输出中可见线程名为 `VirtualThread[...]`，且可创建大量线程而不会像平台线程那样占满系统资源。

---

## 二、记录模式（Record Patterns，JEP 440）

**作用**：在 `instanceof` 和 `switch` 中直接对 record 做模式匹配并解构出组件，避免先强转再 getter。

```java
record Point(int x, int y) {}
record Line(Point p1, Point p2) {}

public class RecordPatternDemo {
    static void print(Object obj) {
        if (obj instanceof Point(int x, int y)) {
            System.out.println("Point: " + x + ", " + y);
        } else if (obj instanceof Line(Point(int x1, int y1), Point(int x2, int y2))) {
            System.out.println("Line: (" + x1 + "," + y1 + ") -> (" + x2 + "," + y2 + ")");
        }
    }

    static String formatter(Object obj) {
        return switch (obj) {
            case Point(int x, int y) -> "Point(" + x + "," + y + ")";
            case Line(Point a, Point b) -> "Line(" + a + "," + b + ")";
            case null -> "null";
            default -> obj.toString();
        };
    }

    public static void main(String[] args) {
        print(new Point(1, 2));
        print(new Line(new Point(0, 0), new Point(1, 1)));
        System.out.println(formatter(new Point(3, 4)));
    }
}
```

需要补上 `import java.util.stream.IntStream;` 若使用上面 VirtualThreadDemo 里的 IntStream。

---

## 三、Switch 模式匹配（JEP 441，转正）

**作用**：与 Java 17 的预览一脉相承，在 switch 的 case 中使用类型模式、null 分支、守卫条件等，并支持穷尽性检查（尤其配合密封类）。

```java
public class SwitchDemo {
    static String describe(Object obj) {
        return switch (obj) {
            case String s when s.length() > 5 -> "long string: " + s;
            case String s -> "string: " + s;
            case Integer i -> "int: " + i;
            case null -> "null";
            default -> "other: " + obj.getClass().getSimpleName();
        };
    }

    public static void main(String[] args) {
        System.out.println(describe("hello"));
        System.out.println(describe("hello world"));
        System.out.println(describe(42));
    }
}
```

---

## 四、有序集合接口（SequencedCollection，JEP 431）

**作用**：为“有顺序”的集合定义统一接口，提供 `getFirst()`、`getLast()`、`reversed()`、`addFirst`/`addLast` 等，便于编写通用顺序敏感代码。

```java
import java.util.*;

public class SequencedDemo {
    public static void main(String[] args) {
        SequencedCollection<String> list = new ArrayList<>(List.of("a", "b", "c"));
        System.out.println(list.getFirst());   // a
        System.out.println(list.getLast());     // c
        System.out.println(list.reversed());   // [c, b, a]

        SequencedMap<String, Integer> map = new LinkedHashMap<>(Map.of("x", 1, "y", 2));
        System.out.println(map.firstEntry());  // x=1
        System.out.println(map.lastEntry());   // y=2
    }
}
```

---

## 五、未命名类与实例 main 方法（JEP 445，预览）

**作用**：允许没有显式类声明的单文件程序，以及实例方法形式的 `main`，降低入门门槛。

```java
// 无需 public class，可直接写顶层代码；main 也可以是实例方法
void main() {
    System.out.println("Hello, Java 21!");
}
```

需用 `java --enable-preview --source 21 UnnamedMain.java` 运行（文件名随意）。

---

## 六、作用域值（Scoped Values，JEP 446，预览）

**作用**：可替代部分 ThreadLocal 场景，在线程内不可变、可继承地传递上下文，更适合虚拟线程。

---

## 七、字符串模板（JEP 430，预览）

**作用**：简化字符串插值，使用 STR 等模板处理器。

```java
// 预览特性，需 --enable-preview --source 21
// String name = "Java";
// String msg = STR."Hello, \{name}!";
```

---

## 八、其它重要 JEP 概览

| JEP | 说明 |
|-----|------|
| **439** | 分代式 ZGC，降低 GC 开销 |
| **442** | 外部函数与内存 API（第三次预览） |
| **443** | 未命名模式与变量（预览） |
| **448** | 向量 API（第六轮孵化） |
| **452** | 密钥封装机制 API |
| **453** | 结构化并发（预览） |
| **449** | 弃用 Windows 32-bit x86 移植 |
| **451** | 准备禁用代理的动态加载（安全） |

---

## 九、小结

| 类别 | 特性 | 一句话 |
|------|------|--------|
| 并发 | 虚拟线程 | 轻量线程，一请求一线程模型友好 |
| 语言 | 记录模式 | instanceof/switch 中解构 record |
| 语言 | Switch 模式匹配 | case 类型模式、null、守卫，穷尽检查 |
| API | 有序集合 | getFirst/getLast/reversed 等统一接口 |
| 语言/预览 | 未命名类与 main、作用域值、字符串模板 | 简化入门与上下文传递 |
| GC/安全 | 分代 ZGC、KEM、平台与代理 | 性能与安全增强 |

以上示例在 JDK 21 下可运行（预览特性需加 `--enable-preview --source 21`）。Java 21 是当前首选 LTS，虚拟线程与模式匹配是升级的最大动力。
