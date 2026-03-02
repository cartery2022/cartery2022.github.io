---
title: 设计模式（九）装饰器模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 装饰器
  - Decorator
  - Spring
categories:
  - 设计模式
  - 结构型
---

# 装饰器模式（Decorator）

## 一、模式概述

**装饰器模式**动态地给对象增加职责，比继承更灵活；装饰器与被装饰对象实现同一接口，内部持有被装饰对象，在调用前后增加行为。

**解决的问题**：需要在不修改原类的前提下，为对象增加额外行为（如日志、缓存、加密）；若用继承，每种组合一个子类会爆炸，装饰器可任意叠放。

**与代理的区别**：装饰器强调“增强、包装”，代理常强调“控制访问、延迟”；实现上类似，都是“实现同一接口 + 持有目标 + 前后增强”。

---

## 二、结构与角色

- **Component**：抽象组件，被装饰对象与装饰器的共同接口。
- **ConcreteComponent**：具体被装饰对象。
- **Decorator**：装饰器，实现 Component 并持有 Component，通常将请求转发给被装饰对象并在前后加逻辑。
- **ConcreteDecorator**：具体装饰器，增加具体职责。

**示例**：

```java
interface Component { String operation(); }
class ConcreteComponent implements Component {
    public String operation() { return "data"; }
}
class Decorator implements Component {
    protected final Component target;
    Decorator(Component target) { this.target = target; }
    public String operation() { return target.operation(); }
}
class LogDecorator extends Decorator {
    LogDecorator(Component target) { super(target); }
    public String operation() {
        System.out.println("before");
        String r = target.operation();
        System.out.println("after");
        return r;
    }
}
```

---

## 三、在 Spring 中的运用

- **TransactionAwareCacheDecorator**：对 `Cache` 做装饰，在事务提交/回滚时再写缓存或清理，使缓存与事务语义一致。
- **BeanWrapper 与 属性编辑器**：对 Bean 的包装与编辑可视为对“对象行为”的装饰。
- **InputStream/OutputStream 装饰**：Java I/O 中 `BufferedInputStream` 装饰 `InputStream` 等；Spring 的 `Resource` 包装（如 `EncodedResource`）也是装饰思想。
- **AOP 切面**：从效果上，对 Bean 方法加事务、日志、权限，相当于对“方法调用”做多层装饰，Spring 用代理实现而非手写装饰类。

---

## 四、适用业务场景

- **动态叠加能力**：如对“读数据”叠加缓存、日志、限流、脱敏，可任意组合且不修改原类。
- **与事务/生命周期挂钩**：如“缓存在事务提交后写入”，用装饰器包装原有 Cache 实现。
- **兼容老接口**：老接口返回的数据需要在新逻辑里做一层包装（如加版本、加元数据），用装饰器包装返回值。
- **流式/管道处理**：数据流经多道处理（压缩、加密、校验），每道用装饰器包装上一级流。

**不适用**：行为固定、不需要多种组合增强时，直接继承或一个工具类即可。

---

## 五、小结

装饰器模式通过“实现同一接口 + 持有被装饰对象 + 前后增强”动态增加职责；Spring 中 **TransactionAwareCacheDecorator**、**Resource 包装**、**AOP 增强** 体现了装饰思想。业务上适用于**动态叠加能力、与事务/生命周期挂钩、兼容老接口、流式处理**等场景。
