---
title: Java 原子类详解与 JDK 演进
date: 2025-03-02
tags:
  - java
  - 原子类
  - 并发
categories:
  - Java
  - 源码解读
---

# Java 原子类详解与 JDK 演进

本文从 JDK 源码视角说明 **Atomic 原子类**（`java.util.concurrent.atomic`）的实现原理、常见类型与使用边界，并按时间顺序梳理版本演进。该主题早于 Java 8 已存在，故**知识点演变从 Java 8 起**叙述。

---

## 一、什么是原子类

原子类提供**无锁（lock-free）**的并发更新能力，核心是：

- **`volatile` 可见性**：读写对线程可见。
- **CAS（Compare-And-Set）**：比较并交换，失败则重试。
- **有限语义的原子复合操作**：如 `incrementAndGet`、`getAndAdd`、`compareAndSet`。

它们适合“单变量状态并发更新”，避免了 `synchronized` 的阻塞与上下文切换开销。

---

## 二、Atomic 家族总览

### 2.1 基础数值与引用类

- **`AtomicInteger` / `AtomicLong` / `AtomicBoolean`**
- **`AtomicReference<T>`**

### 2.2 数组与字段更新器

- **`AtomicIntegerArray` / `AtomicLongArray` / `AtomicReferenceArray`**
- **`AtomicIntegerFieldUpdater` / `AtomicLongFieldUpdater` / `AtomicReferenceFieldUpdater`**

字段更新器用于“对已有类的 `volatile` 字段做 CAS”，避免再包一层对象。

### 2.3 解决 ABA 与高并发计数

- **`AtomicStampedReference`**：引用 + 版本号（stamp），常用于规避 ABA。
- **`AtomicMarkableReference`**：引用 + 1bit 标记。
- **`LongAdder` / `LongAccumulator` / `DoubleAdder` / `DoubleAccumulator`**（位于 `java.util.concurrent.atomic`，实现依赖 `Striped64`）：高并发热点计数下通常优于单点 CAS。

---

## 三、源码实现原理（核心）

### 3.1 `AtomicInteger`：CAS 自旋

`AtomicInteger` 的常见写法是“读取旧值 -> 计算新值 -> CAS 提交”，失败则重试。`getAndIncrement` 的语义可概括为：

```java
public final int getAndIncrement() {
    for (;;) {
        int current = get();
        int next = current + 1;
        if (compareAndSet(current, next))
            return current;
    }
}
```

这类循环在低冲突场景非常高效；高冲突时 CAS 失败率上升，会浪费 CPU。

### 3.2 字段为何是 `volatile`

典型实现里都有类似：

```java
private volatile int value;
```

- `volatile` 保证 `get()` 读取到最新值（可见性）。
- CAS 负责“检查 + 更新”原子性。

仅有 `volatile` 不足以实现 `i++` 原子性；必须配合 CAS 或锁。

### 3.3 `compareAndSet` 到 JVM 的路径

历史上（早期 JDK）很多原子类通过 **Unsafe** 完成 CAS。Java 9 引入 VarHandle 后，JDK 内部逐步转向标准化原子访问路径；对应用层来说，`compareAndSet` 等 API 语义保持一致。

可理解为：

- API 层：`compareAndSet(expected, update)`
- JDK 层：映射到字段偏移 + 原子指令
- CPU 层：借助硬件原子指令（如 x86 的 `cmpxchg`）

### 3.4 `LongAdder`：分段热点，降低冲突

`LongAdder` 不是单一 `value`，而是：

- 低冲突时更新 `base`
- 高冲突时将更新分散到 `Cell[]`（每线程命中不同槽位）
- `sum()` 时汇总 `base + 所有 Cell`

这是一种“空间换时间”的并发策略：写多读少场景吞吐更好，但 `sum()` 不是线性化瞬时值（统计口径通常可接受）。

---

## 四、典型源码片段与语义

### 4.1 `AtomicReference` 与 ABA

`AtomicReference` 只比较“当前引用是否等于 expected”。若值从 A->B->A，普通 CAS 会误判“没变化”，即 ABA 问题。  
若业务对“中间是否变化过”敏感，应使用 **`AtomicStampedReference`**。

### 4.2 字段更新器的约束

`AtomicIntegerFieldUpdater.newUpdater(...)` 对字段要求严格：

- 目标字段必须是 **`volatile`**
- 不能是 `final`
- 访问权限必须满足调用方与目标类的可见性规则

它的优势是“就地更新字段，不新增包装对象”，代价是反射/访问检查更复杂。

### 4.3 原子类不等于“整体线程安全”

只把一个字段换成 `AtomicInteger`，并不自动保证对象其它字段的一致性。  
多个变量之间有不变式（invariant）时，仍需锁、事务或更高层并发控制。

---

## 五、知识点演变（自 Java 8 起按时间顺序）

Atomic 体系早于 Java 8 已存在；本节从 Java 8 起按发布时间顺序叙述，不向前追溯。

### 5.1 Java 8

- Atomic 基础类、数组类、字段更新器、`AtomicStampedReference/MarkableReference` 已是成熟基线。
- `LongAdder` / `LongAccumulator` 成为高并发计数场景常用方案。

### 5.2 Java 9

- **VarHandle（JEP 193）** 引入，JDK 原子访问模型标准化。
- Atomic 类新增一批更细粒度内存语义方法（如 **`getAcquire` / `setRelease` / `getOpaque` / `setOpaque`**）与交换类方法（如 **`compareAndExchange`** 系列），便于与底层内存模型对齐。

### 5.3 Java 11

- 以实现稳定化和性能微调为主，API 语义延续 Java 9 的扩展。
- JUC 内部（如 AQS 等）进一步采用 VarHandle 路径，与 Atomic 家族在实现理念上趋同。

### 5.4 Java 17 / 21 及以后

- 原子类 API 整体稳定，更多是 HotSpot/JDK 内部优化与维护。
- 虚拟线程时代（Java 21）并不改变 Atomic 的使用语义；原子类仍是无锁状态位、计数器、引用切换的基础工具。

### 5.5 小结表

| 顺序 | 版本 | 要点 |
|------|------|------|
| ① | **Java 8** | Atomic 家族与 LongAdder 基线成熟 |
| ② | **Java 9** | VarHandle 引入；Atomic 增加 acquire/release/opaque 与 exchange 能力 |
| ③ | **Java 11** | 稳定化与实现层统一 |
| ④ | **17/21+** | API 稳定，持续优化维护 |

---

## 六、选型建议

| 场景 | 推荐 |
|------|------|
| 单变量计数、状态位 | `AtomicInteger/Long/Boolean` |
| 高并发计数热点（写多读少） | `LongAdder` |
| 需要 CAS 更新对象引用 | `AtomicReference` |
| 需要识别 ABA | `AtomicStampedReference` |
| 想就地更新已有字段 | `Atomic*FieldUpdater` |
| 多变量一致性事务 | `synchronized` / `ReentrantLock` / 更高层方案 |

---

## 七、小结

Java 原子类本质是 **`volatile + CAS + 重试`** 的并发原语封装：在“单变量并发更新”场景可显著降低阻塞成本。源码层面可抓住两条主线：  
1）`AtomicInteger` 这类“单点 CAS 自旋”；  
2）`LongAdder` 这类“分散冲突、汇总读取”。  
从版本演进看，自 Java 8 起能力已完整，Java 9 通过 VarHandle 与更细粒度内存语义方法完成标准化，之后以稳定与优化为主。
