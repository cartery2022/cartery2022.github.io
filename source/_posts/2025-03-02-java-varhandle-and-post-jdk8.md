---
title: VarHandle 详解与 Java 8 之后的发展
date: 2025-03-02
tags:
  - java
  - VarHandle
  - 并发
  - 内存模型
categories:
  - Java
  - 并发
---

# VarHandle 详解与 Java 8 之后的发展

**说明**：`VarHandle` 在 **Java 9** 才通过 **JEP 193** 正式引入标准库。**Java 8 及以前没有 `VarHandle`**；本文先讲 VarHandle 是什么、怎么用，再按时间线说明 **Java 9 起** 的能力扩展与在 JDK 内部的落地。

---

## 一、为什么会出现 VarHandle

在 VarHandle 之前，若要对**普通对象的字段**或**数组元素**做带顺序语义的读/写、`compareAndSet`、`getAndAdd` 等操作，常见做法是：

- 用 **`AtomicInteger`** 等专用原子类（多一层引用与间接访问），或  
- 用 **`Atomic*FieldUpdater`**（写法和性能上往往不理想），或  
- 使用 **`sun.misc.Unsafe`**（不安全、非标准、不可移植）。

**JEP 193（Java 9）** 引入 **`java.lang.invoke.VarHandle`**，目标包括：

- **安全**：类型匹配、边界检查、**`final` 实例字段不可写** 等规则与字节码一致，不会把 JVM 搞到不可靠状态。  
- **性能**：意图与 `Unsafe` 类操作接近，HotSpot 可做 **intrinsic**，生成与 Unsafe 相近的机器码（在可行处）。  
- **可用性**：API 比 Unsafe 清晰；统一的**访问模式**表达不同内存排序语义。

---

## 二、VarHandle 是什么

`VarHandle` 是**对某一“变量位置”的类型化引用**：该位置可以是**实例字段、静态字段、数组元素**，以及 `ByteBuffer` 视图等（视 JDK 版本与支持类型而定）。

对变量的访问不直接暴露“地址”，而是通过 **签名多态（signature polymorphic）** 的方法，例如：

- `get` / `set`：普通（plain）读写。  
- `getVolatile` / `setVolatile`：与 `volatile` 类似的可见性与有序性。  
- `getAcquire` / `setRelease`：常用于与 release/acquire 配对。  
- `compareAndSet`、`weakCompareAndSet`、`compareAndExchange`：CAS。  
- `getAndSet`、`getAndAdd`：读-改-写。  
- **Java 11 起**：`getAndBitwiseOr`、`getAndBitwiseAnd`、`getAndBitwiseXor` 及其 acquire/release 变体等。  
- **内存栅栏**：`fullFence`、`acquireFence`、`releaseFence`、`loadLoadFence`、`storeStoreFence`（静态方法）。  
- **可达性**：`reachabilityFence` 保证对象在语义上仍被强引用（与 GC 交互场景有用）。

---

## 三、如何获取 VarHandle

通常通过 **`MethodHandles.Lookup`**：

```java
import java.lang.invoke.MethodHandles;
import java.lang.invoke.VarHandle;

public class Demo {
    private volatile int x;

    private static final VarHandle X_HANDLE;

    static {
        try {
            X_HANDLE = MethodHandles.lookup()
                .findVarHandle(Demo.class, "x", int.class);
        } catch (ReflectiveOperationException e) {
            throw new ExceptionInInitializerError(e);
        }
    }

    public void casDemo() {
        // 等价思想：原子地把 x 从 0 改成 1
        boolean ok = X_HANDLE.compareAndSet(this, 0, 1);
    }
}
```

**注意**：

- `Lookup` 的访问规则与反射一致（模块导出/ `opens`、**private** 需 `privateLookupIn` 等）。  
- 对 **数组** 用 `MethodHandles.arrayElementVarHandle(int[].class)` 等。

---

## 四、访问模式与内存语义（概念）

不同方法对应 JMM 中不同的读/写与同步效果，可粗分为：

| 类别 | 典型方法 | 含义（简化理解） |
|------|----------|------------------|
| Plain | `get` / `set` | 无额外同步承诺，可被重排序优化 |
| Volatile | `getVolatile` / `setVolatile` | 与 volatile 字段类似的可见性与 hb 关系 |
| Acquire/Release | `getAcquire` / `setRelease` | 单侧排序，常用于与另一端的 release/acquire 配对 |
| Opaque | `getOpaque` / `setOpaque` | 可见性保证、排序弱于 volatile，具体见 Javadoc |
| RMW | `compareAndSet`、`getAndAdd` 等 | 原子读-改-写，方法上注明各自的内存排序 |

编写并发代码时应**以 Javadoc 与 JLS 为准**，本节只做导读。

---

## 五、Java 8 之后的发展时间线

### 5.1 Java 8 及以前

- **无 `VarHandle`**。  
- 并发原子操作用 **`java.util.concurrent.atomic`**、**Unsafe**（内部）、或 **`synchronized` / `volatile`**。

### 5.2 Java 9：JEP 193，VarHandle 首次发布

- **`java.lang.invoke.VarHandle`** 与配套 Lookup API。  
- 覆盖实例/静态字段、数组元素等；提供上述多类访问模式与 fence、`reachabilityFence`。  
- 为后续 **JUC、JDK 内部逐步替换 Unsafe 字段访问** 打下基础。

### 5.3 Java 11：位运算原子 API + 内部广泛使用

- VarHandle 增加 **`getAndBitwiseOr` / `And` / `Xor`** 及带 **Acquire/Release** 语义的变体，以及按位相关的单比特操作等（具体以当前 JDK `VarHandle` Javadoc 列举为准），更贴近硬件上的原子位操作能力。  
- **AbstractQueuedSynchronizer（AQS）** 等对**同步状态**的 CAS 等实现，迁移到以 **VarHandle** 实现原子更新（如 **JDK-8149644** 一类变更），减少对 `Unsafe` 的依赖，**应用层 `ReentrantLock` 等 API 不变**。

### 5.4 Java 12 及以后

- `VarHandle` 作为稳定 API，随版本补充文档与小改进；**核心模型仍是 JEP 193 + Java 11 的位运算扩展**。  
- 应用层若未使用新增方法，一般无需改代码。  
- 与 **Foreign Memory / Panama（如 `MemorySegment`）** 等走的是另一套 API（不同 JEP），和“堆内字段上的 VarHandle”互补而不是替代关系。

### 5.5 小结表

| 版本 | 与 VarHandle 相关的内容 |
|------|-------------------------|
| **≤ 8** | 无 VarHandle |
| **9** | JEP 193：VarHandle 与全套基础访问模式 |
| **11** | 位运算类原子方法；AQS 等内部改用 VarHandle |
| **12+** | 持续维护；与 Panama 等并存 |

---

## 六、简单示例：getAndAdd

```java
import java.lang.invoke.MethodHandles;
import java.lang.invoke.VarHandle;

public class CounterHolder {
    private volatile long counter;
    private static final VarHandle COUNTER;

    static {
        try {
            COUNTER = MethodHandles.lookup()
                .findVarHandle(CounterHolder.class, "counter", long.class);
        } catch (ReflectiveOperationException e) {
            throw new ExceptionInInitializerError(e);
        }
    }

    public long increment() {
        return (long) COUNTER.getAndAdd(this, 1L);
    }
}
```

（生产环境可继续优先用 **`AtomicLong`**；VarHandle 更适合**自定义数据结构**或**与现有字段布局强绑定**的场景。）

---

## 七、何时用 VarHandle

| 更适合 VarHandle | 更适合 Atomic / synchronized |
|------------------|-------------------------------|
| 需要对**现有类字段**做 CAS/有序访问且不想单独包一层原子类 | 单一计数器、累加器等，**Atomic\*** 更直观 |
| 实现**无锁数据结构**、与内存排序精细控制 | 普通互斥，**`synchronized`** 或 **Lock** 足够 |
| 库/框架作者，依赖 **标准 API** 替代 Unsafe | 业务代码很少需要直接碰 VarHandle |

---

## 八、小结

- **VarHandle 自 Java 9 起存在**，不是 Java 8 的 API；Java 8 之后的发展即 **9 起引入、11 增强位运算与 JDK 内部迁移**。  
- 它提供**类型安全、有 JMM 语义说明**的字段/元素原子与有序访问，是 **`Unsafe` 字段操作** 的标准替代方向之一。  
- **Java 11** 在 VarHandle 上扩展了**按位原子**能力，并推动 **AQS** 等核心类用 VarHandle 实现状态更新；之后版本以**稳定演进**为主。  
- 日常业务优先 **`java.util.concurrent`** 与 **`synchronized`**；**VarHandle** 面向需要**精细内存语义**或 **JDK/框架级** 实现的场景。
