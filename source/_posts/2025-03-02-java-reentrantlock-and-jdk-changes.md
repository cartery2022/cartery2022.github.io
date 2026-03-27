---
title: ReentrantLock 详解与 Java 8 之后版本相关改动
date: 2025-03-02
tags:
  - java
  - ReentrantLock
  - AQS
  - 并发
  - 虚拟线程
categories:
  - Java
  - 并发
---

# ReentrantLock 详解与 Java 8 之后版本相关改动

本文说明 **ReentrantLock** 的定位、与 `synchronized` 的差异、核心 API、底层与 **AbstractQueuedSynchronizer（AQS）** 的关系，以及 **Java 8 之后各版本** 与可重入锁相关的实现与生态变化（VarHandle、AQS 内部实现、虚拟线程与“锁”等）。

---

## 一、ReentrantLock 是什么

`ReentrantLock` 位于 `java.util.concurrent.locks` 包，实现 `Lock` 接口，提供**可重入的互斥锁**：

- **可重入**：同一线程可多次 `lock()`，需相应次数 `unlock()` 才真正释放。
- **显式加解锁**：不在 JVM 监视器（`synchronized`）语义内，必须手写 `lock()` / `unlock()`，通常放在 `try/finally` 里保证释放。
- **公平/非公平**：构造时可选 `new ReentrantLock(true)` 为**公平锁**（大致按排队顺序获取）；默认 **false** 为**非公平**，吞吐量通常更高。

内部依赖 **AQS**（`AbstractQueuedSynchronizer`）维护状态与**FIFO 等待队列**，`LockSupport.park/unpark` 阻塞/唤醒线程。

---

## 二、与 synchronized 的对比

| 对比项 | synchronized | ReentrantLock |
|--------|--------------|---------------|
| **语法** | 关键字，自动在块结束时释放 | 显式 `lock`/`unlock` |
| **可中断** | 阻塞不可被中断 | `lockInterruptibly()` 可响应中断 |
| **超时/尝试** | 无 | `tryLock()`、`tryLock(time, unit)` |
| **条件队列** | `wait`/`notify` 绑定一个条件 | `newCondition()` 可多个 `Condition` |
| **公平性** | 非公平 | 可选公平或非公平 |
| **作用域** | 块结构，易避免忘记释放 | 更灵活，但需自己保证在 finally 中 `unlock` |

**选型建议**：大多数互斥场景 `synchronized` 足够且更简单；需要**可中断、定时获取、多条件、公平策略**或与其他 Lock API 统一建模时用 `ReentrantLock`。

---

## 三、核心 API 用法

### 3.1 标准写法

```java
ReentrantLock lock = new ReentrantLock();
lock.lock();
try {
    // 临界区
} finally {
    lock.unlock();
}
```

### 3.2 可中断获取

```java
lock.lockInterruptibly();
try {
    // ...
} finally {
    lock.unlock();
}
```

等待过程中线程可被 `interrupt()`，抛出 `InterruptedException`；适合可取消的长任务。

### 3.3 尝试与定时获取

```java
if (lock.tryLock()) {
    try {
        // ...
    } finally {
        lock.unlock();
    }
} else {
    // 未拿到锁的降级逻辑
}

if (lock.tryLock(3, TimeUnit.SECONDS)) {
    try {
        // ...
    } finally {
        lock.unlock();
    }
}
```

### 3.4 Condition（多条件等待）

```java
ReentrantLock lock = new ReentrantLock();
Condition notEmpty = lock.newCondition();
Condition notFull = lock.newCondition();

lock.lock();
try {
    while (queue.isEmpty()) notEmpty.await();
    // 取元素
    notFull.signal();
} finally {
    lock.unlock();
}
```

---

## 四、实现原理简述（AQS）

- `ReentrantLock` 内部有一个 `Sync` 继承 **AQS**，用 **state** 表示重入次数：首次获取为 1，同线程再次 `lock` 则 `state++`，`unlock` 时 `state--`，到 0 才真正释放。
- **非公平**：新来的线程可能插队抢锁（在实现允许的情况下），减少上下文切换，通常更快。
- **公平**：先检查队列中是否有等待者，尝试减少“饥饿”，但吞吐量可能略低。

AQS 使用 **CAS** 更新状态、**CLH 变体队列** 管理等待节点，阻塞时使用 `LockSupport.park`，唤醒用 `unpark`。这些在 Java 8 及以后大方向一致，**JDK 内部的具体原子实现**在 8 之后有演进（见下节）。

---

## 五、Java 8 之后与 ReentrantLock 相关的改动

下面区分：**对外 API** 与 **JVM/JUC 内部实现**，以及与 **虚拟线程** 的关系。

### 5.1 Java 9：VarHandle（JEP 193）铺好底层基础设施

- Java 9 引入 **VarHandle**，提供类型安全、规范化的字段/数组/静态变量的细粒度访问（含 volatile、CAS 等），旨在替代部分 **sun.misc.Unsafe** 用法。
- **`ReentrantLock` 的公开 API 在 Java 9 未做破坏性变更**；变化主要在 JUC 底层逐步采用更规范的内存访问原语。

### 5.2 Java 11：AQS 等同步器内部迁移到 VarHandle（JDK-8149644 等）

- **AbstractQueuedSynchronizer** 等对 **state** 的 CAS、volatile 读写等，在 JDK 11 前后改为通过 **VarHandle** 完成，减少对 Unsafe 的直接依赖，语义更清晰，便于维护与优化。
- 对应用开发者而言：**调用方式不变**，**行为与内存模型语义仍与 JLS 监视器/锁规则一致**；可能带来实现层面的性能微调，但一般无需改代码。

### 5.3 Java 8 已存在、常与 ReentrantLock 对比的 API：StampedLock

- **StampedLock**（Java 8 引入）不是 `ReentrantLock` 的替代品提供互斥的简单升级版，而是**读写 + 乐观读**的另一套模型；**不可重入**，且无 `Condition`。
- **读多写少**且能接受更复杂用法时，可考虑 `StampedLock`；**需要可重入或 Condition** 时仍用 `ReentrantLock` / `ReentrantReadWriteLock`。

### 5.4 Java 21：虚拟线程（JEP 444）与锁

- **虚拟线程**在阻塞时（包括通过 JUC 锁等待）使用 **pinning 较少** 的路径时，由运行时调度到 `LockSupport.park`，可释放底层载体线程给其它虚拟线程使用。
- **`synchronized` 在 JDK 21 中仍可能导致虚拟线程“钉住”（pin）平台线程**，高并发阻塞在监视器上会压缩虚拟线程优势；在虚拟线程环境下，**需要长时间持锁或复杂阻塞时，更倾向使用 `ReentrantLock` 等 `java.util.concurrent` 锁**，这也是官方文档与实践中常提到的差异之一。
- **JEP 491（JDK 24 起）**：改进 **synchronized** 与虚拟线程的配合，减少 pin；**不替代**按需使用 `ReentrantLock` 的场景，但缩小了“只用 JVM 监视器”的劣势。

### 5.5 小结表（对应用代码的含义）

| 版本区间 | 与 ReentrantLock 最相关的内容 |
|----------|-------------------------------|
| **Java 8** | API 形态稳定；与 `StampedLock` 并存 |
| **Java 9** | VarHandle 引入，为后续 JUC 内部改写奠基 |
| **Java 11** | AQS 等内部广泛使用 VarHandle，**API 不变** |
| **Java 21** | 虚拟线程：**JUC 锁**与 `synchronized` 对虚拟线程的友好度差异需纳入设计 |
| **JDK 24+** | `synchronized` 与虚拟线程行为改进（JEP 491），策略上可多评估是否仍需显式 Lock |

---

## 六、实践注意点

1. **必须在 finally 中 `unlock`**，且**仅释放在本线程成功获取的锁**；`tryLock` 失败时不要 `unlock`。
2. **可重入**：递归或同线程嵌套调用若都 `lock`，必须成对 `unlock`，否则泄漏或死锁。
3. **Condition 使用**：须在持有对应 `lock` 时 `await`/`signal`，语义类似 `wait`/`notify` 但粒度可多路。
4. **性能**：默认非公平锁通常优于公平锁；公平锁用于对“饥饿”极敏感的场景。
5. **虚拟线程**：大量阻塞在锁上的逻辑，优先考虑 **JUC Lock** + 短临界区，避免在 `synchronized` 里长时间阻塞（JDK 21 尤其如此）。

---

## 七、小结

**ReentrantLock** 提供可重入互斥、可中断与定时获取、多 `Condition`，底层由 **AQS** 实现。Java 8 之后**公开 API 保持稳定**；**Java 9–11** 一代主要改进是 **VarHandle 与 AQS 内部实现**；**Java 21+** 在**虚拟线程**场景下，`ReentrantLock` 等 JUC 锁与 `synchronized` 的取舍成为架构关注点；**JDK 24+** 通过 **JEP 491** 缓解 `synchronized` 与虚拟线程的 pin 问题。掌握显式锁的用法与这些演进，有助于写出更安全、可维护的并发代码。
