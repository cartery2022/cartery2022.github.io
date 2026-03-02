---
title: 设计模式（十）外观模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 外观
  - Facade
  - Spring
categories:
  - 设计模式
  - 结构型
---

# 外观模式（Facade）

## 一、模式概述

**外观模式**为子系统中的一组接口提供一个统一的高层接口，使子系统更易使用。

**解决的问题**：子系统内类多、接口复杂，客户若直接依赖多个类则耦合高、调用繁琐；外观提供一个“门面”，把常用流程封装成简单接口。

**定义**：为子系统中的一组接口提供一个一致的界面，Facade 定义了一个高层接口，使子系统更易使用。

---

## 二、结构与角色

- **Facade**：外观类，持有子系统若干模块的引用，提供少量高层方法，内部编排对子系统的调用。
- **Subsystem classes**：子系统中的多个类，各自负责一部分功能；客户可通过 Facade 间接使用，也可直接使用（若需要细粒度控制）。

**示例**：

```java
class ModuleA { void doA() {} }
class ModuleB { void doB() {} }
class ModuleC { void doC() {} }

public class Facade {
    private final ModuleA a = new ModuleA();
    private final ModuleB b = new ModuleB();
    private final ModuleC c = new ModuleC();
    public void doOneThing() {
        a.doA();
        b.doB();
        c.doC();
    }
}
```

---

## 三、在 Spring 中的运用

- **SpringMVC 的 DispatcherServlet**：对请求处理流程的统一入口，内部编排 HandlerMapping、HandlerAdapter、ViewResolver 等，对“一次 HTTP 请求”提供“查 Handler → 适配执行 → 解析视图”的简化视图，是典型外观。
- **JdbcTemplate**：对 JDBC 的 Connection/Statement/ResultSet 的获取、异常转换、资源关闭做封装，对外提供 `query/update` 等简单 API，降低直接使用 JDBC 的复杂度。
- **Spring Boot 的自动配置与 Starter**：如 `spring-boot-starter-web` 对外暴露“开箱即用”的 Web 能力，背后整合 Tomcat、MVC、Jackson 等，可视为“模块组”的外观。
- **Tomcat 的 RequestFacade / ResponseFacade**：对 ServletRequest/ServletResponse 的封装，隐藏内部实现细节，避免用户拿到内部对象后误操作。

---

## 四、适用业务场景

- **简化子系统使用**：如“下单”涉及库存、订单、支付、消息等多个服务，对外提供 `OrderFacade.placeOrder()`，内部编排调用，减少调用方对多模块的依赖。
- **统一入口与流程**：如“报表生成”需查库、计算、导出，用 ReportFacade 封装步骤，调用方只调一个方法。
- **降低升级影响**：子系统内部重构时，只要外观接口不变，调用方无需改动。
- **为第三方/遗留系统提供简版 API**：把复杂、难用的 API 包一层，只暴露业务需要的少量方法。

**不适用**：调用方需要细粒度控制子系统每一步、或子系统本身很简单时，不必强行加外观。

---

## 五、小结

外观模式通过“统一高层接口 + 内部编排子系统”降低使用复杂度；Spring 中 **DispatcherServlet**、**JdbcTemplate**、**Boot Starter**、**RequestFacade/ResponseFacade** 都是外观思想的体现。业务上适用于**简化多模块调用、统一流程入口、隔离变化、包装复杂 API** 等场景。
