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

## 十一、Java 9 及以后对线程池相关 API 的改动

### 11.1 CompletableFuture 增强（Java 9）

- **completeOnTimeout(value, timeout, unit)**：超时未完成则用给定值完成。
- **orTimeout(timeout, unit)**：超时未完成则以 **TimeoutException** 异常完成。
- **defaultExecutor()**：子类可重写，自定义默认执行器，不必每次传 Executor。
- **newIncompleteFuture()**：工厂方法，便于子类扩展。
- **completedStage()** / **failedStage()** / **failedFuture()** 等：创建已完成或已失败的 CompletableFuture/CompletionStage。

这些改动不改变“线程池”本身，但让异步任务与超时、默认 Executor 的配合更灵活。

### 11.2 虚拟线程与 Executor（Java 21）

- **Executors.newVirtualThreadPerTaskExecutor()**：为**每个任务**创建一个**虚拟线程**，任务结束后虚拟线程可被回收；适合“一任务一线程”的模型，无需再维护传统线程池的队列与最大线程数上限。
- **Executors.newThreadPerTaskExecutor(ThreadFactory)**：按给定 **ThreadFactory** 为每个任务创建新线程；若传入 **Thread.ofVirtual().factory()**，效果与上面类似（虚拟线程）。
- 虚拟线程由 JVM 调度，可创建大量虚拟线程而只占少量平台线程，适合高并发 I/O；**现有 ExecutorService 接口不变**，只是实现从“固定线程+队列”变为“每任务一虚拟线程”。

示例：

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

### 11.3 其它版本

- **Java 8**：Lambda、CompletableFuture 的引入使“异步 + 线程池”成为标配。
- **Java 9+**：模块化后 `java.util.concurrent` 仍在 java.base，无 API 破坏性变更；线程池本身行为稳定，改动主要集中在 CompletableFuture（9）和虚拟线程 Executor（21）。

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
