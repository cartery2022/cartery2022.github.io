---
title: 设计模式（十四）命令模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 命令
  - Spring
categories:
  - 设计模式
  - 行为型
---

# 命令模式（Command）

## 一、模式概述

**命令模式**将请求封装成对象，从而可用不同的请求对客户进行参数化、支持请求排队、记录日志、撤销等。

**解决的问题**：把“操作”变成对象，便于传递、排队、记录、撤销/重做；调用方只依赖“命令”接口，不依赖具体执行者。

**定义**：将请求封装为对象，从而可以参数化客户、排队、记录请求日志、支持撤销等。

---

## 二、结构与角色

- **Command**：抽象命令，声明 execute()（及可选 undo()）。
- **ConcreteCommand**：具体命令，持有 Receiver 的引用，execute() 中调用 Receiver 的相应方法。
- **Receiver**：接收者，真正执行操作的对象。
- **Invoker**：调用者，持有 Command，在适当时机调用 command.execute()。
- **Client**：组装 Command 与 Receiver，将 Command 交给 Invoker。

**示例**：

```java
interface Command { void execute(); }
class Receiver {
    public void action() { System.out.println("do"); }
}
class ConcreteCommand implements Command {
    private final Receiver receiver = new Receiver();
    public void execute() { receiver.action(); }
}
class Invoker {
    private Command command;
    public void setCommand(Command c) { this.command = c; }
    public void run() { command.execute(); }
}
```

---

## 三、在 Spring 中的运用

- **Runnable / Callable 作为“命令”**：线程池提交的 Runnable/Callable 可视为命令对象，Invoker 是线程池，Receiver 是业务逻辑；Spring 的 @Async、TaskExecutor 也基于此类“可执行命令”。
- **JdbcTemplate 的 StatementCreator / PreparedStatementCallback**：将“创建语句/执行语句”封装成对象，由模板在合适时机（获取连接后）执行，具有命令模式思想。
- **Spring MVC 的 HandlerExecutionChain**：Handler 与 Interceptor 可视为“命令 + 链”，DispatcherServlet 作为 Invoker 在合适时机执行。
- **消息驱动**：MQ 消息体可视为“命令”，消费者根据消息类型执行不同逻辑，支持异步、排队、重试。

---

## 四、适用业务场景

- **撤销/重做**：每次操作封装成命令并入栈，撤销时执行 undo 或从栈中弹出并反向执行。
- **任务队列、异步执行**：任务封装成命令对象，放入队列，由工作线程依次执行；支持延迟、重试、优先级。
- **多端触发同一操作**：UI、API、定时任务都可发出同一“命令对象”，由统一 Invoker 执行，便于扩展与测试。
- **审计、日志**：命令对象可记录“谁在何时执行了什么”，便于审计与回放。
- **宏/批处理**：将多个命令组合成复合命令，一次执行一批操作。

**不适用**：操作极简单、无需排队/撤销/审计时，直接调用即可。

---

## 五、小结

命令模式通过“将请求封装为对象”支持参数化、排队、撤销、审计；Spring 中 **Runnable/Callable 与线程池**、**JdbcTemplate 回调**、**消息驱动** 体现了命令思想。业务上适用于**撤销重做、任务队列、多端触发、审计、宏/批处理**等场景。
