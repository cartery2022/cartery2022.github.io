---
title: Java 17 新特性总结与示例
date: 2025-03-02
tags:
  - java
  - Java17
  - LTS
  - 密封类
  - 模式匹配
categories:
  - Java
---

# Java 17 新特性总结与示例

Java 17 于 **2021 年 9 月 14 日** 正式发布，是 **继 Java 8 以来重要的长期支持（LTS）版本**，支持至 2029 年 9 月。Spring 6.x / Spring Boot 3.x 的最低支持版本即为 Java 17。本文按语言、API、平台等分类梳理主要新特性，并配有示例（基于 JDK 17）。

---

## 一、密封类（Sealed Classes，JEP 409）

**作用**：用 `sealed` + `permits` 限制“谁可以继承/实现”当前类或接口，编译器可做穷尽性检查，提高类型安全。

```java
// 密封接口：只允许 Circle、Square、Rectangle 实现
public sealed interface Shape permits Circle, Square, Rectangle {
    double area();
}

final class Circle implements Shape {
    private final double r;
    Circle(double r) { this.r = r; }
    @Override public double area() { return Math.PI * r * r; }
}

final class Square implements Shape {
    private final double side;
    Square(double side) { this.side = side; }
    @Override public double area() { return side * side; }
}

final class Rectangle implements Shape {
    private final double w, h;
    Rectangle(double w, double h) { this.w = w; this.h = h; }
    @Override public double area() { return w * h; }
}
```

子类必须为 `final`、`sealed` 或 `non-sealed` 之一。与 switch 模式匹配结合时，编译器可检查是否覆盖所有 permitted 类型，无需 default。

---

## 二、Switch 模式匹配（JEP 406，预览 → 后续版本转正）

**作用**：在 switch 的 case 中使用类型模式，并可直接绑定变量，简化“按类型分派”的代码。

```java
public class SwitchPatternDemo {
    static String formatter(Object obj) {
        return switch (obj) {
            case Integer i -> "int: " + i;
            case Long l    -> "long: " + l;
            case Double d -> "double: " + d;
            case String s  -> "string: " + s;
            case null      -> "null";
            default        -> obj.getClass().getSimpleName();
        };
    }

    public static void main(String[] args) {
        System.out.println(formatter(1));       // int: 1
        System.out.println(formatter("hi"));    // string: hi
        System.out.println(formatter(null));   // null
    }
}
```

与密封类结合时，对密封类型的 switch 可做穷尽性检查，无需 default。

---

## 三、强封装 JDK 内部 API（JEP 403）

默认不再允许反射访问 JDK 内部 API（如 `sun.*`），除非使用 `--add-opens` 等打开模块。目的是提高稳定性和安全性，避免依赖未承诺的内部实现。

---

## 四、其它重要 JEP 概览

| JEP | 说明 |
|-----|------|
| **410** | 移除实验性 AOT/JIT 编译器 |
| **411** | 弃用安全管理器（计划删除） |
| **407** | 移除 RMI 激活机制 |
| **398** | 弃用 Applet API |
| **382** | 新 macOS 渲染管道 |
| **391** | macOS/AArch64（Apple Silicon）支持 |
| **306** | 恢复“始终严格”的浮点语义 |
| **415** | 上下文反序列化过滤器（安全） |
| **412** | 外部函数与内存 API（孵化） |
| **414** | 向量 API（第二轮孵化） |
| **356** | 增强的伪随机数生成器 |

---

## 五、伪随机数生成器（JEP 356）

新 API 位于 `java.util.random`，提供 `RandomGenerator` 接口及多种算法实现（如 `L32X64MixRandom`），便于在测试与生产中选择可复现或高性能的随机源。

```java
import java.util.random.*;

public class RandomDemo {
    public static void main(String[] args) {
        RandomGenerator gen = RandomGenerator.of("L32X64MixRandom");
        System.out.println(gen.nextInt(100));
    }
}
```

---

## 六、小结

| 类别 | 特性 | 一句话 |
|------|------|--------|
| 语言 | 密封类 | 限制子类型，便于穷尽 switch |
| 语言 | Switch 模式匹配 | case 中类型模式 + 绑定变量 |
| 平台 | 强封装、移除/弃用 | 内部 API 不可随意反射，RMI 激活/Applet 等移除或弃用 |
| 平台 | macOS/AArch64、新渲染 | 支持 Apple Silicon 等 |
| API/孵化 | 新随机数、FFM、向量 API | 随机数增强，本地/向量为孵化 |

以上示例在 JDK 17 下可运行。Java 17 是当前主流 LTS 之一，适合作为新项目或从 8/11 升级的目标版本。
