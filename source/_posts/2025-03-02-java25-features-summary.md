---
title: Java 25 新特性总结与示例
date: 2025-03-02
tags:
  - java
  - Java25
categories:
  - Java
  - 新版本特性
---

# Java 25 新特性总结与示例

Java 25 于 **2025 年 9 月 16 日** 正式发布，是 **新的长期支持（LTS）版本**。本文按语言、API、并发、GC 与平台等分类梳理主要新特性，并配有示例（基于 JDK 25）。

---

## 一、语言层面

### 1.1 模式中的基本类型（JEP 507，第三轮预览）

**作用**：在 `instanceof` 和 `switch` 的模式中直接支持基本类型，避免不必要的装箱/拆箱。

```java
public class PrimitivePatternDemo {
    static String describe(Object obj) {
        return switch (obj) {
            case int i -> "int: " + i;
            case long l -> "long: " + l;
            case double d -> "double: " + d;
            case boolean b -> "boolean: " + b;
            case null -> "null";
            default -> "other: " + obj.getClass().getSimpleName();
        };
    }

    public static void main(String[] args) {
        System.out.println(describe(42));
        System.out.println(describe(3.14));
    }
}
```

（实际语法以 JDK 25 最终规范为准，可能需 `--enable-preview`。）

### 1.2 模块导入声明（JEP 511，预览）

**作用**：使用 `import module` 一次性导入某模块导出的所有包，简化模块化库的复用。

```java
// 预览特性示例（语法以最终规范为准）
// import module java.sql;
```

### 1.3 紧凑源文件与实例 main 方法（JEP 512，转正）

**作用**：无显式类声明的顶层代码、实例 main 方法成为正式特性；`IO` 类用于控制台 I/O，位于 `java.lang` 并隐式导入，便于入门与脚本式程序。

### 1.4 灵活的构造器体（JEP 513，转正）

**作用**：允许在显式 `super()` 或 `this()` 调用之前执行语句，放宽构造器体的书写顺序，便于做参数校验或辅助计算后再调用父类或本类构造器。

```java
public class FlexibleConstructorDemo {
    private final int value;

    public FlexibleConstructorDemo(int value) {
        // 可在 super()/this() 前执行逻辑
        if (value < 0) throw new IllegalArgumentException("value >= 0");
        this.value = value;
    }
}
```

---

## 二、API 与并发

### 2.1 作用域值（Scoped Values，JEP 506，转正）

**作用**：线程内不可变的、可继承的上下文传递，替代部分 ThreadLocal 场景，更适合虚拟线程。

```java
public class ScopedValueDemo {
    private static final ScopedValue<String> USER = ScopedValue.newInstance();

    public static void main(String[] args) throws Exception {
        ScopedValue.where(USER, "alice").run(() -> {
            System.out.println(USER.get());  // alice
        });
    }
}
```

### 2.2 密钥派生函数 API（JEP 510，转正）

**作用**：提供标准化的密钥派生（KDF）API，用于密钥拉伸、从密码派生密钥等密码学场景。

### 2.3 结构化并发（JEP 505，第五轮预览）

**作用**：用结构化方式管理并发任务的生命周期和异常传播，与虚拟线程配合使用，代码更清晰。

---

## 三、向量 API（JEP 508，第十轮孵化）

**作用**：与平台无关的 SIMD 风格向量运算 API，便于利用 CPU 向量指令做高性能计算（仍为孵化 API，包名可能含 `incubator`）。

---

## 四、GC 与运行时

| JEP | 说明 |
|-----|------|
| **521** | 分代式 Shenandoah（转正），优化 GC 行为 |
| **519** | 紧凑对象头（转正），减少对象内存占用 |
| **520** | JFR 方法计时与追踪（转正），增强 profiling 能力 |
| **503** | 移除 32-bit x86 移植，平台瘦身 |

---

## 五、小结

| 类别 | 特性 | 一句话 |
|------|------|--------|
| 语言 | 模式中的基本类型 | instanceof/switch 直接匹配基本类型 |
| 语言 | 模块导入、紧凑源文件、灵活构造器 | 模块化与语法便利 |
| 并发/API | 作用域值、结构化并发 | 上下文传递与并发结构规范化 |
| 安全/API | 密钥派生函数 | 标准化 KDF |
| 性能/平台 | 向量 API、分代 Shenandoah、紧凑对象头、JFR、移除 32-bit | 性能与可观测性、平台精简 |

以上示例在 JDK 25 下可运行（预览/孵化特性需相应编译与运行参数）。Java 25 作为新 LTS，适合作为新一轮升级与长期支持的目标版本。
