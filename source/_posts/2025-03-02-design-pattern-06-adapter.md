---
title: 设计模式（六）适配器模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 适配器
  - Spring
categories:
  - 设计模式
  - 结构型
---

# 适配器模式（Adapter）

## 一、模式概述

**适配器模式**将一个类的接口转换成客户期望的另一种接口，使原本接口不兼容的类可以一起工作。

**解决的问题**：已有类（或第三方库）的接口与当前系统期望的接口不一致，又不能改源码时，通过适配器做“转换层”。

**两种形式**：**类适配器**（继承被适配类并实现目标接口）、**对象适配器**（持有被适配者引用并实现目标接口，更常用）。

---

## 二、结构与角色

- **Target**：目标接口，客户依赖的接口。
- **Adaptee**：被适配者，已有但接口不兼容的类。
- **Adapter**：实现 Target，内部持有或继承 Adaptee，把对 Target 的调用转发并转换为对 Adaptee 的调用。

**示例（对象适配器）**：

```java
interface Target { void request(); }
class Adaptee {
    public void specificRequest() { System.out.println("adapted"); }
}
class Adapter implements Target {
    private final Adaptee adaptee = new Adaptee();
    public void request() { adaptee.specificRequest(); }
}
```

---

## 三、在 Spring 中的运用

- **Spring AOP 的 MethodInterceptor 适配**：如 `MethodBeforeAdviceAdapter` 将 `MethodBeforeAdvice` 适配成 `MethodInterceptor`，供统一拦截链使用；`AfterReturningAdviceAdapter` 等同理。
- **HandlerAdapter（Spring MVC）**：将多种 Controller 类型（`@RequestMapping`、Servlet、HttpRequestHandler 等）统一适配成 `ModelAndView handle(request, response, handler)` 的调用方式，DispatcherServlet 只依赖 HandlerAdapter 接口。
- **Spring MVC 的 ViewResolver / View**：将逻辑视图名适配为具体 View 实现（JSP、JSON、模板等）。
- **JPA 的 Repository 实现**：Spring Data 将“方法名/注解”适配成持久化操作，也是对“接口”的适配。

---

## 四、适用业务场景

- **对接遗留或第三方接口**：老系统或第三方库接口与现有接口不一致，加一层适配器统一成当前系统接口，不改老代码。
- **统一多种实现**：多种数据源、多种协议（HTTP/gRPC/消息）需要统一成同一抽象（如统一成“调用接口”），每种实现包一层适配器。
- **版本兼容**：新旧 API 共存期，用适配器把旧 API 转成新 API 形态，便于逐步迁移。
- **与 AOP/拦截器对接**：不同风格的“增强”（Advice 类型）需要统一成同一拦截接口时，用适配器转换。

**不适用**：能直接改接口或统一抽象时，优先重构而非堆适配器。

---

## 五、小结

适配器模式通过“实现目标接口 + 转发到被适配者”解决接口不兼容；Spring 中 **HandlerAdapter**、**Advice 适配成 MethodInterceptor** 是典型应用。业务上适用于**对接遗留/第三方、统一多种实现、版本兼容、AOP 链统一**等场景。
