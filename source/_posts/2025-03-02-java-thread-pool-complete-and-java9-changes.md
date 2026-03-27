---
title: Java 线程池知识点与 Java 9+ 改动
date: 2025-03-02
tags:
  - java
  - 线程池
  - ThreadPoolExecutor
  - Executor
  - 虚拟线程
categories:
  - Java
  - 并发
---

# Java 线程池知识点与 Java 9+ 改动

本文梳理 **Java 线程池** 的完整知识点：体系结构、核心参数、任务流程、拒绝策略、Executors 工厂方法、ForkJoinPool 与定时任务，以及 **Java 9 及以后版本** 对线程池与相关 API 的改动（CompletableFuture 增强、虚拟线程 Executor 等）。

---

## 一、体系结构

```
Executor（接口）
    └── ExecutorService（接口）
            └── AbstractExecutorService（抽象类）
                    ├── ThreadPoolExecutor（通用线程池）
                    ├── ScheduledThreadPoolExecutor（定时/周期任务）
                    └── ForkJoinPool（分治/工作窃取）
```

- **Executor**：只定义 `void execute(Runnable command)`，表示“执行任务”。
- **ExecutorService**：扩展了提交任务（submit 返回 Future）、关闭（shutdown/shutdownNow）、批量执行（invokeAll/invokeAny）等。
- **ThreadPoolExecutor**：最常用的实现，通过**核心线程数、最大线程数、队列、拒绝策略**等控制行为。

---

## 二、ThreadPoolExecutor 核心参数

构造方法（7 个参数）：

```text
ThreadPoolExecutor(
    int corePoolSize,
    int maximumPoolSize,
    long keepAliveTime,
    TimeUnit unit,
    BlockingQueue<Runnable> workQueue,
    ThreadFactory threadFactory,
    RejectedExecutionHandler handler
)
```

| 参数 | 含义 |
|------|------|
| **corePoolSize** | 核心线程数，常驻池中，空闲时默认不回收（除非开启 allowCoreThreadTimeOut） |
| **maximumPoolSize** | 最大线程数，池中线程总数上限 |
| **keepAliveTime** | 非核心线程空闲超过该时间会被回收；单位由 unit 指定 |
| **unit** | keepAliveTime 的时间单位 |
| **workQueue** | 任务队列，存放尚未被线程执行的任务 |
| **threadFactory** | 创建新线程的工厂，可自定义线程名、优先级等 |
| **handler** | 当“线程数已达 maximum 且队列已满”时的拒绝策略 |

---

## 三、任务提交流程

`execute(Runnable command)` 的大致逻辑：

1. **当前线程数 < corePoolSize**：创建新**核心线程**执行该任务。
2. **当前线程数 ≥ corePoolSize**：尝试将任务**放入 workQueue**。
3. **队列已满**：尝试创建**非核心线程**（不超过 maximumPoolSize）执行该任务。
4. **无法创建新线程**（已达 maximum 且队列满）：执行 **RejectedExecutionHandler**（拒绝策略）。

因此：**先占满核心线程 → 再填队列 → 再开非核心线程 → 再拒绝**。  
使用**无界队列**时，不会走到“队列满”，也就不会创建非核心线程，maximumPoolSize 形同虚设。

### 3.1 源码：`ThreadPoolExecutor.execute`（OpenJDK 主干）

**`ctl`** 是高 3 位的**运行状态**与低 29 位的**工作线程数**的 **`AtomicInteger` 打包字段**；**`workerCountOf`** / **`runStateOf`** 从中解码。下面摘录与面试常背顺序**一一对应**：

```java
public void execute(Runnable command) {
    if (command == null)
        throw new NullPointerException();
    int c = ctl.get();
    if (workerCountOf(c) < corePoolSize) {
        if (addWorker(command, true))
            return;
        c = ctl.get();
    }
    if (isRunning(c) && workQueue.offer(command)) {
        int recheck = ctl.get();
        if (!isRunning(recheck) && remove(command))
            reject(command);
        else if (workerCountOf(recheck) == 0)
            addWorker(null, false);
    }
    else if (!addWorker(command, false))
        reject(command);
}
```

- **第一支**：`workerCount < core` 时 **`addWorker(command, true)`**（`true` 表示占用**核心**名额）；失败则重新读 **`ctl`**（并发下别的线程可能已改池状态）。
- **第二支**：已至少 **`core`** 个 worker 时 **`workQueue.offer`**；入队成功后 **double-check**：若池已 **SHUTDOWN** 等则 **`remove` 任务并 `reject`**；若此时 **worker 数为 0**（例如刚被回收完）要 **`addWorker(null, false)`** 保证有线程去拉队列。
- **第三支**：队列 **`offer` 失败**（有界队列满）时 **`addWorker(command, false)`** 尝试以**非核心**身份起线程；仍失败则 **`reject(command)`**。

**`addWorker`** 内部会 **`new Worker(firstTask)`**、**`workers` 集合登记**、**`t.start()`**，Worker 的 **`run`** 里调 **`runWorker`** 循环从队列 **`getTask`** 取作业执行。

---

## 四、任务队列（workQueue）常见类型

| 队列类型 | 特点 | 典型用法 |
|----------|------|----------|
| **LinkedBlockingQueue**（无界） | 容量可视为无限，不触发拒绝 | 任务量可控、希望“削峰”时 |
| **ArrayBlockingQueue**（有界） | 固定容量，满则走非核心/拒绝 | 需要限制排队数量时 |
| **SynchronousQueue** | 不存元素，移交即被取走 | 配合“大 maximumPoolSize”做直接交接 |
| **DelayQueue** | 按延迟时间取出 | 延迟任务（也可用 ScheduledExecutorService） |

---

## 五、拒绝策略（RejectedExecutionHandler）

当“线程数 = maximumPoolSize 且 workQueue 满”时触发。

| 策略 | 行为 |
|------|------|
| **AbortPolicy**（默认） | 抛出 **RejectedExecutionException** |
| **CallerRunsPolicy** | 由**提交任务的线程**直接执行该任务，相当于“调用者自己跑” |
| **DiscardPolicy** | 静默丢弃任务，不抛异常 |
| **DiscardOldestPolicy** | 丢弃队列中**最早**的一个任务，再把当前任务入队 |

可自定义实现 **RejectedExecutionHandler**，做打日志、入库、转存等。

---

## 六、Executors 工厂方法及注意点

| 方法 | 内部实现要点 | 常见问题 |
|------|--------------|----------|
| **newFixedThreadPool(n)** | 核心=最大=n，**无界** LinkedBlockingQueue | 任务过多时队列无限增长，易 OOM |
| **newCachedThreadPool()** | 核心=0，最大=Integer.MAX_VALUE，**SynchronousQueue** | 任务多时线程数暴增，易耗尽资源 |
| **newSingleThreadExecutor()** | 核心=最大=1，无界队列 | 同上，队列无界 |
| **newScheduledThreadPool(n)** | 定时任务线程池，DelayedWorkQueue | 核心线程数可设为 0 或较小，需结合业务 |

**建议**：生产环境尽量用 **ThreadPoolExecutor 构造器** 显式指定有界队列、合理 maximum、自定义 ThreadFactory 和拒绝策略，避免直接用上述“无界”工厂。

---

## 七、关闭：shutdown 与 shutdownNow

- **shutdown()**：不再接受新任务，已提交的任务会继续执行完；池不会立刻退出。
- **shutdownNow()**：不再接受新任务，并**尝试中断**正在执行的任务，返回**尚未执行的任务列表**；对不响应中断的任务无法强制停止。
- **awaitTermination(long timeout, TimeUnit unit)**：阻塞当前线程，直到池关闭或超时；常与 shutdown 配合使用，先 shutdown 再 awaitTermination 等待一段时间。

典型用法：

```java
executor.shutdown();
if (!executor.awaitTermination(60, TimeUnit.SECONDS)) {
    executor.shutdownNow();
}
```

---

## 八、扩展点与其它配置

- **allowCoreThreadTimeOut(boolean)**：为 true 时，核心线程在空闲 keepAliveTime 后也会被回收；默认 false。
- **beforeExecute(Thread t, Runnable r)** / **afterExecute(Runnable r, Throwable t)**：子类可重写，在任务执行前后打日志、统计等。
- **setCorePoolSize** / **setMaximumPoolSize**：运行时可动态调整（需注意与当前队列、线程数的关系）。

---

## 九、ForkJoinPool 与 ScheduledExecutorService

### 9.1 ForkJoinPool

- 面向**分治、可递归拆分的任务**（如大数组并行计算），使用 **work-stealing**：空闲线程从其它线程的队列尾部“偷”任务。
- **ForkJoinPool.commonPool()**：JVM 内共享的通用池，默认线程数约 CPU 核数 - 1；**CompletableFuture** 默认使用该池，不适合大量 I/O 或阻塞任务，建议显式传入自定义 Executor。

### 9.2 ScheduledExecutorService

- **schedule(command, delay, unit)**：延迟一次执行。
- **scheduleAtFixedRate** / **scheduleWithFixedDelay**：周期执行。
- 实现类 **ScheduledThreadPoolExecutor** 继承 ThreadPoolExecutor，使用 **DelayedWorkQueue**；核心线程数可设为 0 或较小，一般不建议对调度池开启 allowCoreThreadTimeOut，以免无线程可用。

---

## 十、CompletableFuture 与线程池

- **CompletableFuture.supplyAsync(supplier)** / **runAsync(runnable)** 等**不传 Executor** 时，使用 **ForkJoinPool.commonPool()**。
- commonPool 线程数少，且针对 CPU 密集型设计；**I/O 多或阻塞多**时易成为瓶颈，甚至低核数机器上退化为“每任务一线程”。
- **建议**：**始终传入业务专用线程池**，例如 `CompletableFuture.supplyAsync(supplier, customExecutor)`，且 thenApplyAsync 等也尽量传同一 Executor，避免混用 commonPool。

---

## 十一、知识点演变（自 Java 8 起按时间顺序）

`ThreadPoolExecutor` 等早于 Java 8 已存在；本节从 **Java 8** 起按版本发布时间叙述与**线程池 + 异步**最相关的 API 变化，不向前追溯。

### 11.1 Java 8

- **Lambda** 与 **`CompletableFuture`** 进入标准库，“提交到 **`ExecutorService`** + 链式异步”成为常见写法。

### 11.2 Java 9

- **JPMS**：`java.util.concurrent` 归入 **java.base**，对典型应用**无破坏性迁移**。
- **CompletableFuture** 增强：**completeOnTimeout**、**orTimeout**、可重写的 **defaultExecutor()** /**newIncompleteFuture()**、**completedStage** / **failedStage** / **failedFuture** 等。
- **`ThreadPoolExecutor` 等行为保持稳定**；改动侧重**异步编排与超时**。

### 11.3 Java 21

- **Executors.newVirtualThreadPerTaskExecutor()**：每任务一**虚拟线程**，适合高并发 I/O、“一任务一线程”模型。
- **Executors.newThreadPerTaskExecutor(ThreadFactory)**：配合 **`Thread.ofVirtual().factory()`** 同上思路。
- **`ExecutorService` 接口不变**；实现从传统“固定平台线程 + 队列”扩展到虚拟线程调度。

```java
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    IntStream.range(0, 10_000).forEach(i ->
        executor.submit(() -> {
            Thread.sleep(Duration.ofSeconds(1));
            return i;
        })
    );
}
```

### 11.4 小结表

| 顺序 | 版本 | 要点 |
|------|------|------|
| ① | **Java 8** | Lambda + CompletableFuture + 线程池标配用法 |
| ② | **Java 9** | CompletableFuture 超时与工厂方法 |
| ③ | **Java 21** | 虚拟线程 Executor |

---

## 十二、小结

| 主题 | 要点 |
|------|------|
| **体系** | Executor → ExecutorService → ThreadPoolExecutor / ScheduledThreadPoolExecutor / ForkJoinPool |
| **核心参数** | corePoolSize、maximumPoolSize、keepAliveTime、workQueue、threadFactory、handler |
| **流程** | 先占满核心线程 → 再入队 → 再开非核心线程 → 再拒绝 |
| **队列** | 无界队列易 OOM；有界队列 + 合理 maximum + 拒绝策略更稳妥 |
| **拒绝策略** | AbortPolicy、CallerRunsPolicy、DiscardPolicy、DiscardOldestPolicy 及自定义 |
| **关闭** | shutdown + awaitTermination，必要时 shutdownNow |
| **CompletableFuture** | 务必传自定义 Executor，避免 commonPool；Java 9 增加超时与默认 Executor 扩展 |
| **Java 21** | newVirtualThreadPerTaskExecutor、newThreadPerTaskExecutor(ThreadFactory) 支持虚拟线程，适合高并发 I/O 场景 |

掌握以上内容即可覆盖日常开发与面试中对 Java 线程池的要求，并在 Java 9+ 中正确使用 CompletableFuture 与虚拟线程 Executor。
