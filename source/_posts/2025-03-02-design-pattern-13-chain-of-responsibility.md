---
title: 设计模式（十三）责任链模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 责任链
  - Spring
categories:
  - 设计模式
  - 行为型
---

# 责任链模式（Chain of Responsibility）

## 一、模式概述

**责任链模式**使多个对象都有机会处理请求，将这些对象连成一条链，并沿链传递请求，直到有对象处理为止。

**解决的问题**：请求的发送者与多个处理者解耦，处理者可动态组合、顺序可调，且可随时增删节点。

**定义**：将请求的发送者和接收者解耦，使多个对象都有机会处理该请求；将这些对象连成链，并沿链传递请求。

---

## 二、结构与角色

- **Handler**：抽象处理者，定义处理接口并持有后继者（next），在 handle 中可选地调用 next.handle()。
- **ConcreteHandler**：具体处理者，能处理则处理并返回，否则交给后继。

**示例**：

```java
abstract class Handler {
    protected Handler next;
    public void setNext(Handler next) { this.next = next; }
    abstract void handle(Request req);
}
class HandlerA extends Handler {
    void handle(Request req) {
        if (canHandle(req)) { /* 处理 */ return; }
        if (next != null) next.handle(req);
    }
    private boolean canHandle(Request req) { return true; }
}
```

---

## 三、在 Spring 中的运用

- **Filter 链（Servlet / Spring Security）**：请求依次经过多个 Filter，每个 Filter 可决定是否放行、是否继续链；Spring Security 的 FilterChainProxy 编排多个 SecurityFilter，是责任链。
- **HandlerInterceptor**：Spring MVC 中 preHandle/postHandle/afterCompletion 构成“拦截链”，多个 Interceptor 按顺序执行，任一 preHandle 返回 false 可中断。
- **AOP 的 Advice 链**：多个 Advisor/Advice 组成拦截链，按顺序执行，可视为责任链。
- **异常解析链**：HandlerExceptionResolver 有多个实现，按顺序尝试解析异常，直到某个能处理为止。

---

## 四、适用业务场景

- **多级审批、工作流**：请求按“一级 → 二级 → 三级”传递，每级能处理则处理并结束，否则交给下一级。
- **请求预处理/后处理**：如鉴权 → 限流 → 日志 → 业务，每步可中断或放行。
- **异常/错误处理**：多种异常处理器按顺序尝试，直到某个能处理（转换、记录、返回统一格式）。
- **管道式处理**：数据经多道“处理器”（校验、转换、丰富、落库），每道可选处理或跳过。

**不适用**：请求必然只由一个固定对象处理、或处理逻辑无“链式传递”需求时。

---

## 五、小结

责任链模式通过“处理者持有后继 + 沿链传递请求”实现发送者与多个处理者解耦；Spring 中 **Filter/FilterChain**、**HandlerInterceptor**、**AOP 链**、**HandlerExceptionResolver** 是典型应用。业务上适用于**多级审批、请求预处理链、异常解析链、管道处理**等场景。
