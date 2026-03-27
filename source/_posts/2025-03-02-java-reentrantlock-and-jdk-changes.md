---
title: ReentrantLock 详解与 JDK 演进
date: 2025-03-02
tags:
  - java
  - ReentrantLock
  - 并发
categories:
  - Java
  - 并发
---

# ReentrantLock 详解与 JDK 演进

本文说明 **ReentrantLock** 的定位、与 `synchronized` 的差异、核心 API、底层与 **AbstractQueuedSynchronizer（AQS）** 的关系，以及**与实现、运行环境相关**的版本演进（均以 **Java 8 为叙述起点**：该类早于 Java 8 已存在，不再向前追溯）。

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

## 四、源码走读（OpenJDK 主干）

以下与 **`java.util.concurrent.locks.ReentrantLock`**、`NonfairSync` / `FairSync`、**`AbstractQueuedSynchronizer`** 的公开源码结构一致，便于把 API 与实现对应起来（具体行号随 JDK 版本略有差异）。

### 4.1 类层次与 `state`

- 对外 **`ReentrantLock`** 只委托内部 **`Sync extends AbstractQueuedSynchronizer`**，再分子类 **`NonfairSync`**、**`FairSync`**。
- **`state`（volatile int）** 在互斥锁语义下：**0** 表示无占用；若当前**独占线程**是本线程，则 **`state` 为重入次数**（每次 `lock` 对应 `+1`，`unlock` 对应 `-1`，减到 **0** 才完全释放）。

### 4.2 非公平 `lock()`：先 CAS 抢一次

`NonfairSync.lock()` 里典型顺序是：若 **`compareAndSetState(0, 1)`** 成功，则 **`setExclusiveOwnerThread(Thread.currentThread())`** 并返回；否则走 **`acquire(1)`**。这就是“新来的线程**可能插队**”的来源——在未入队前就有机会直接拿到锁，减少 **`park`** / 上下文切换。

公平锁的 `FairSync.lock()` 通常直接 **`acquire(1)`**，把是否允许抢锁交给 **`tryAcquire`**（见下）。

### 4.3 `tryAcquire`：可重入 + 公平队列判断

公平与否的差异集中在 **`tryAcquire(int acquires)`**。公平版在 `state == 0` 时会先 **`hasQueuedPredecessors()`**：若同步队列里已有更早等待的节点，则**不 CAS**，避免饥饿；非公平版在 `state == 0` 时往往**直接 CAS**。  
两版在 **`current == getExclusiveOwnerThread()`** 时都做 **`setState(c + acquires)`**，实现**可重入**。

```java
// FairSync.tryAcquire —— 逻辑结构与 OpenJDK 一致（省略溢出检查细节）
protected final boolean tryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    if (c == 0) {
        if (!hasQueuedPredecessors() && compareAndSetState(0, acquires)) {
            setExclusiveOwnerThread(current);
            return true;
        }
    } else if (current == getExclusiveOwnerThread()) {
        int nextc = c + acquires;
        if (nextc < 0)
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    return false;
}
```

### 4.4 AQS 模板：`acquire` / `release` 与 `LockSupport`

`tryAcquire` 失败则进入 AQS 的公共路径：**入队、自旋再 `park`、被释放方 `unpark`**。

```java
// AbstractQueuedSynchronizer
public final void acquire(int arg) {
    if (!tryAcquire(arg) &&
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}
```

- **`addWaiter`**：当前线程封装为 **`Node`**，挂到 **CLH 风格双向 FIFO 队列**。
- **`acquireQueued`**：在队列中按需自旋尝试 `tryAcquire`，失败后 **`LockSupport.park`**。

释放时 **`unlock()`** → **`release(1)`**：子类 **`tryRelease`** 把 `state` 减到 0 并 **`setExclusiveOwnerThread(null)`** 返回 true 后，AQS 调用 **`unparkSuccessor`** 唤醒后继。

### 4.5 `state` 的 CAS 实现与后文「知识点演变」

**`compareAndSetState` / `getState` / `setState`** 在较早 JDK 中常基于 **Unsafe**，自 **Java 11** 起在 AQS 内普遍改为 **`VarHandle`**，**对外语义不变**。下节按版本说明这些演进。

---

## 五、知识点演变（自 Java 8 起按时间顺序）

`ReentrantLock` / AQS 早于 Java 8 已存在；读者侧约定从 **Java 8** 起按版本发布时间顺序叙述，不向前追溯。

### 5.1 Java 8

- **公开 API**：`lock` / `tryLock` / `lockInterruptibly`、`Condition`、`公平/非公平` 等与当今用法一致，可视为稳定基线。
- **并列 API**：**StampedLock**（读写 + 乐观读，**不可重入**、无 `Condition`），与 `ReentrantLock` 场景互补。
- **底层**：AQS 的 `state` 仍多依赖 **Unsafe** 等路径做 CAS（实现细节随版本而变）。

### 5.2 Java 9

- **VarHandle**（JEP 193）进入标准库，为后续用规范原子 API 替代部分 Unsafe 用法铺路。
- **`ReentrantLock` 对外 API 无破坏性变更**。

### 5.3 Java 11

- **AQS** 对 **`state`** 的访问普遍改为 **VarHandle**（如 JDK-8149644），减少直接依赖 `sun.misc.Unsafe`；**语义与使用方式不变**。

### 5.4 Java 12～15

- 以 **AQS / 锁相关 bug 修复与实现整理**为主（中断、cancel 竞态、队列一致性等），**不扩展新的锁 API 模型**。

### 5.5 Java 21

- **虚拟线程**（JEP 444）：阻塞在 **JUC 锁**上的等待路径与运行时调度较好配合；**`synchronized`** 仍易 **pin** 平台线程，高压场景下 **`ReentrantLock` 与短临界区** 常被优先讨论。

### 5.6 JDK 24 及以后

- **JEP 491**：改进 **`synchronized` 与虚拟线程**的配合，减轻 pin；与是否继续使用 `ReentrantLock` 的架构选择并行存在。

### 5.7 小结表

| 顺序 | 版本 | 要点 |
|------|------|------|
| ① | **Java 8** | API 基线；`StampedLock` 并存 |
| ② | **Java 9** | VarHandle 基础设施 |
| ③ | **Java 11** | AQS `state` 等走 VarHandle |
| ④ | **12～15** | 正确性为主的小步修复 |
| ⑤ | **Java 21** | 虚拟线程与锁选型 |
| ⑥ | **24+** | `synchronized` 与虚拟线程改进（JEP 491） |

---

## 六、实践注意点

1. **必须在 finally 中 `unlock`**，且**仅释放在本线程成功获取的锁**；`tryLock` 失败时不要 `unlock`。
2. **可重入**：递归或同线程嵌套调用若都 `lock`，必须成对 `unlock`，否则泄漏或死锁。
3. **Condition 使用**：须在持有对应 `lock` 时 `await`/`signal`，语义类似 `wait`/`notify` 但粒度可多路。
4. **性能**：默认非公平锁通常优于公平锁；公平锁用于对“饥饿”极敏感的场景。
5. **虚拟线程**：大量阻塞在锁上的逻辑，优先考虑 **JUC Lock** + 短临界区，避免在 `synchronized` 里长时间阻塞（JDK 21 尤其如此）。

---

## 七、小结

**ReentrantLock** 提供可重入互斥、可中断与定时获取、多 `Condition`，底层由 **AQS** 实现。自 **Java 8** 起对外 API 已稳定；随后 **9～11** 主要是 **AQS 用 VarHandle 管理状态** 等实现层变化；**21** 起 **虚拟线程** 使 JUC 锁与 `synchronized` 的选型更受关注；**24+** 的 **JEP 491** 改善了 `synchronized` 与虚拟线程的配合。写作顺序上：以 Java 8 为起点，按版本递增理解即可。
