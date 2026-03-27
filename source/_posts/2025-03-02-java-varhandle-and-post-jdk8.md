---
title: VarHandle 详解与 JDK 演进
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

# VarHandle 详解与 JDK 演进

**说明**：`VarHandle` 在 **Java 9**（JEP 193）才进入标准库，**此前无对应 API**；本文先讲其用途与用法，**知识点演变从 Java 9 起按时间顺序**叙述（不单独以 Java 8 为起点）。

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

### 4.1 源码与运行时：`Lookup`、签名多态、intrinsic

**`findVarHandle` / `arrayElementVarHandle`** 在 **`java.lang.invoke`** 中解析访问目标并构造 **`VarHandle`**（字段或数组元素的**布局与权限**在句柄创建时即定死）。

`VarHandle` 的 **`get`、`set`、`compareAndSet`** 等为 **`@MethodHandle.PolymorphicSignature`**：编译器按实参类型生成 **`invokeExact` 约定**下的 `invoke`，**不必**为每种类型单独声明一套方法。

JVM 将 **AccessMode** 映射到 **内存排序**；HotSpot 可对 **`compareAndSet`、`getVolatile`** 等做 **intrinsic**，与历史上 **Unsafe** CAS 同级。

---

## 五、知识点演变（自 Java 9 起按时间顺序）

### 5.1 Java 9：JEP 193，首次发布

- 引入 **`java.lang.invoke.VarHandle`** 与配套 **Lookup** API。  
- 覆盖实例/静态字段、数组元素等；提供多类访问模式与 fence、`reachabilityFence`。  
- 为 **JUC / JDK 内部逐步替换 Unsafe 字段访问** 打下基础。

### 5.2 Java 11：位运算原子 API + AQS 等落地 VarHandle

- 增加 **`getAndBitwiseOr` / `And` / `Xor`** 及 **Acquire/Release** 变体等（以当前 JDK Javadoc 为准）。  
- **AQS** 等对同步状态的 CAS 等改为以 **VarHandle** 实现（如 **JDK-8149644**），**`ReentrantLock` 等对外 API 不变**。

### 5.3 Java 12 及以后

- **API 稳定**，以小改进、文档补充为主；与 **Panama / `MemorySegment`** 等堆外访问体系**并行存在、定位不同**。

### 5.4 小结表

| 顺序 | 版本 | 要点 |
|------|------|------|
| ① | **Java 9** | JEP 193，VarHandle 与基础访问模式 |
| ② | **Java 11** | 位运算原子；AQS 等内部用 VarHandle |
| ③ | **12+** | 维护；与 Panama 等并存 |

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

- **VarHandle** 提供**类型安全、有 JMM 语义说明**的字段/元素原子与有序访问，是 **`Unsafe` 字段操作** 的标准替代方向之一。  
- **演变顺序**：**Java 9** 引入 → **Java 11** 扩展位运算原子并让 **AQS** 等用 VarHandle 更新状态 → **12+** 稳定维护并与 Panama 并存。  
- 日常业务优先 **`java.util.concurrent`** 与 **`synchronized`**；**VarHandle** 面向需要**精细内存语义**或 **JDK/框架级** 实现的场景。
