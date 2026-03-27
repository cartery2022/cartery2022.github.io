---
title: AbstractQueuedSynchronizer（AQS）详解与 JDK 演进
date: 2025-03-02
tags:
  - java
  - AQS
  - 并发
  - JUC
categories:
  - Java
  - 并发
---

# AbstractQueuedSynchronizer（AQS）详解与 JDK 演进

本文说明 **AbstractQueuedSynchronizer（AQS）** 的定位、核心结构、独占/共享模式与条件队列，并梳理 **JDK 各版本** 中与 AQS 相关的重要实现变化与缺陷修复（尤其是 **Java 11 起用 VarHandle 管理状态** 及后续维护性更新）。

---

## 一、AQS 是什么

**AQS** 位于 `java.util.concurrent.locks` 包，由 **Doug Lea** 设计，是 JUC 中 **阻塞锁与同步器** 的公共骨架：

- **ReentrantLock**、**ReentrantReadWriteLock**（内部 Sync）
- **Semaphore**
- **CountDownLatch**
- **ThreadPoolExecutor**（Worker 关闭等场景）

等均通过 **继承 AQS** 并实现 `tryAcquire` / `tryRelease`（独占）或 `tryAcquireShared` / `tryReleaseShared`（共享）等钩子，复用 **FIFO 等待队列** 与 **阻塞/唤醒** 逻辑。

**对外**：应用代码通常只用 `Lock`、`Semaphore` 等 API；**AQS 是 `public` 类**，也可被子类扩展实现自定义同步器，但门槛较高。

---

## 二、核心结构

### 2.1 同步状态 state

- **`volatile int state`**：由子类约定语义。
  - **ReentrantLock**：0 表示无主，>0 表示持有次数（可重入）。
  - **Semaphore**：可用许可数。
  - **CountDownLatch**：还剩多少次 countDown。

通过 **`getState()` / `setState()` / `compareAndSetState()`** 读取与原子更新状态（具体底层实现随 JDK 版本演进，见第四节）。

### 2.2 等待队列（CLH 变体）

- **FIFO 双向链表**，节点 `Node` 含：`waitStatus`、`prev`、`next`、`thread` 等。
- **`head` / `tail`** 指向队列头尾（头结点可视为占位，真正等待从其后继开始很常见）。
- 获取失败时线程被封装成 Node **入队**，经自旋后调用 **`LockSupport.park`** 阻塞；释放时 **`unpark`** 后继。

### 2.3 独占与共享

| 模式 | 典型用途 | 模板入口 |
|------|----------|----------|
| **独占（Exclusive）** | 互斥锁 | `acquire` / `release` |
| **共享（Shared）** | 信号量、读锁（阶段） | `acquireShared` / `releaseShared` |

子类实现对应的 **`tryAcquire` / `tryRelease`** 或 **`tryAcquireShared` / `tryReleaseShared`**，返回是否成功；AQS 负责排队、阻塞与唤醒传播（共享模式下可能连续唤醒多个后继）。

### 2.4 条件队列：ConditionObject

- **`ConditionObject`** 是 AQS 的**内部类**，实现 `Condition`。
- 每个 `Condition` 维护**独立于锁等待队列**的条件单向链表；**`await`** 释放锁并进入条件队列，**`signal`** 将节点移回锁等待队列。
- **`ReentrantLock.newCondition()`** 即基于同一套 AQS 状态与队列框架。

### 2.5 兄弟类：AbstractQueuedLongSynchronizer

若 `int` 状态不够（如大范围计数），JDK 提供 **`AbstractQueuedLongSynchronizer`**：**`long` 型 state** 与相同队列语义，用法与 AQS 平行。

---

## 三、典型 acquire / release 流程（概念）

**独占 `acquire`：**

1. 调用子类 **`tryAcquire`**；成功则结束。
2. 失败则 **构造 Node、入队**，在队列中自旋或 **`park`**。
3. 被 **`release` 唤unpark** 后继续竞争 `tryAcquire`。

**`release`：**

1. 调用子类 **`tryRelease`**；成功则唤醒后继（`unparkSuccessor`）。

**共享模式**还会在释放后做 **传播（propagate）**，使多个等待线程在许可充足时依次通过。

### 3.1 源码：`acquire` 与 `addWaiter`（独占）

`AbstractQueuedSynchronizer.acquire` 把**快速路径**留给子类 **`tryAcquire`**，失败则**入队 + 阻塞**：

```java
public final void acquire(int arg) {
    if (!tryAcquire(arg) &&
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}
```

- **`tryAcquire`**：`ReentrantLock.Sync`、`Semaphore.Sync` 等子类实现；成功则直接返回，**不**经过队列。
- **`addWaiter(Node mode)`**：为当前线程创建 **`Node`**（含 **`Thread` 引用、`waitStatus`、`prev`/`next`**），以 CAS 方式拼到 **`tail`**，形成**双向 FIFO**。**`head`** 常作哑节点，真正等待的多从 **`head.next`** 开始参与竞争。
- **`acquireQueued`**：节点入队后，在循环里再次 **`tryAcquire`**；仍失败则 **`shouldParkAfterFailedAcquire`** 决定前驱 **`SIGNAL`** 等状态后，调用 **`LockSupport.park(this)`**；被 **`unpark`** 或中断后醒来再次尝试。

### 3.2 源码：`release` 与唤醒后继

```java
public final boolean release(int arg) {
    if (tryRelease(arg)) {
        Node h = head;
        if (h != null && h.waitStatus != 0)
            unparkSuccessor(h);
        return true;
    }
    return false;
}
```

- **`tryRelease`**：子类实现；**互斥锁**里典型语义是把 **`state`** 还原到 0 并 **`setExclusiveOwnerThread(null)`**。
- **`unparkSuccessor`**：从 **`head`** 向后找**有效后继**（跳过 **`CANCELLED`**），对其 **`Thread`** 调用 **`LockSupport.unpark`**。

### 3.3 `state` 的更新（与 JDK 版本）

**`getState` / `setState` / `compareAndSetState`** 是队列外**可见性与原子性**的根基；现代 OpenJDK 在 `AbstractQueuedSynchronizer` 内对 **`state`** 使用 **`VarHandle`（如 `STATE`）** 做 volatile 读/写与 CAS（**Java 11** 前后从 **Unsafe** 迁出，语义不变）。读懂上述三个方法，`ReentrantLock` / `Semaphore` 的 **`tryAcquire`/`tryRelease`** 只是在这套队列协议上**解释 `state` 的含义**。

### 3.4 共享模式与条件队列（点到为止）

- **共享**：`acquireShared` / `releaseShared` 使用 **`Node.SHARED`**，释放后可能 **`doReleaseShared`** **连续 propagate**，多个等待线程在许可足够时依次通过（如 **`Semaphore`**）。
- **`ConditionObject`**：**`await`** 会 **`fullyRelease`** 释放 **`state`** 并进入**条件单向链表**；**`signal`** 把节点转回**同步队列**尾部，之后走与普通 `acquire` 相同的 **`acquireQueued`** 路径。

---

## 四、知识点演变（自 Java 8 起按时间顺序）

AQS 早于 Java 8 已存在；本节从 **Java 8** 起按版本发布时间叙述，不向前追溯。对外 API（`acquire` / `release` / `Condition` 等）**长期保持稳定**；变化主要在 **状态的原子实现** 与 **队列/中断/取消** 的健壮性。

### 4.1 Java 8

- **`state`** 多通过 **Unsafe** 等做 CAS；框架形态：**state + CLH 风格队列 + `LockSupport`**。

### 4.2 Java 9

- **VarHandle**（JEP 193）进入标准库，为后续规范 **`state`** 访问铺路。

### 4.3 Java 11

- **`compareAndSetState` / `getState` / `setState`** 等改为通过 **VarHandle** 访问 **`state`**（JDK-8149644 等），**语义与公共 API 不变**。

### 4.4 Java 12～15

- **中断与 `tryAcquire`**（8191937）、**cancel 节点** 竞态（8191483）、未持锁 **await**（8187408）、**8229442** 等对 AQS 与相关 lock 的 **bugfix / 刷新**；**不新增抽象模式**。

### 4.5 Java 21 及以后

- **虚拟线程**：基于 **`LockSupport.park`** 的 JUC 锁等待与运行时配合；**`synchronized`** 的 pin 问题使 **`ReentrantLock`（AQS）** 常被对比讨论。**JDK 24+ JEP 491** 改善 `synchronized` 与虚拟线程的配合。

### 4.6 小结表

| 顺序 | 版本 | 要点 |
|------|------|------|
| ① | **Java 8** | Unsafe 管 `state`；队列形态定型 |
| ② | **Java 9** | VarHandle 基础设施 |
| ③ | **Java 11** | `state` 迁 VarHandle |
| ④ | **12～15** | 正确性与实现整理 |
| ⑤ | **21+** | 虚拟线程与锁选型；24+ 同步改进 |

---

## 五、学习与实践建议

1. 读源码时抓住 **`acquire` / `release`** 与 **`Node.waitStatus`** 两条线，再看 **条件队列** `ConditionObject`。
2. 自定义同步器优先评估是否可用 **`Semaphore` / `ReentrantLock`** 组合替代，**直接继承 AQS** 需严谨处理 **`tryRelease` 的返回值与 state 含义**。
3. 关注 **JDK 发行说明** 与 **JDK Bug System** 中带 `AbstractQueuedSynchronizer` 的条目，可获知具体版本行为修复。

---

## 六、小结

**AbstractQueuedSynchronizer** 用 **`volatile int state` + FIFO 等待队列 + LockSupport** 统一实现阻塞式同步；**独占/共享**与 **Condition** 覆盖大部分 JUC 锁与门闩类。自 **Java 8** 起可视为稳定基线；**11** 起 **`state` 经 VarHandle 更新**；**12～15** 多为正确性修复；**21+** 与虚拟线程、`synchronized` 选型相关。公共模板 API 保持稳定。理解 AQS 有助于深入掌握 **Java 并发与锁实现**。
