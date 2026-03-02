---
title: 设计模式（二）工厂方法模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 工厂方法
  - Factory Method
  - Spring
categories:
  - 设计模式
  - 创建型
---

# 工厂方法模式（Factory Method）

## 一、模式概述

**工厂方法模式**定义用于创建对象的接口，由子类决定实例化哪一个类，将对象的创建延迟到子类。

**解决的问题**：避免在业务代码中直接 `new` 具体类，降低耦合，便于扩展新的产品类型。

**定义**：定义一个创建对象的接口，让子类决定实例化哪个类；工厂方法使一个类的实例化延迟到其子类。

---

## 二、结构与角色

- **Product**：抽象产品（接口或抽象类）。
- **ConcreteProduct**：具体产品。
- **Creator**：抽象工厂，声明工厂方法（返回 Product）。
- **ConcreteCreator**：具体工厂，实现工厂方法，返回 ConcreteProduct。

**示例**：

```java
interface Product { void use(); }
class ProductA implements Product { public void use() { System.out.println("A"); } }
class ProductB implements Product { public void use() { System.out.println("B"); } }

abstract class Creator {
    abstract Product createProduct();
    void doSomething() {
        Product p = createProduct();
        p.use();
    }
}
class CreatorA extends Creator {
    Product createProduct() { return new ProductA(); }
}
class CreatorB extends Creator {
    Product createProduct() { return new ProductB(); }
}
```

---

## 三、在 Spring 中的运用

- **BeanFactory / ApplicationContext**：本质是“创建 Bean 的工厂”，`getBean()` 即工厂方法；具体创建哪种 Bean、如何构造由配置与子类/实现决定。
- **FactoryBean**：实现 `FactoryBean<T>` 的 Bean，容器通过 `getObject()` 获取实际要暴露的对象，适合“创建过程复杂、非简单 new”的对象（如 AOP 代理、动态数据源等）。
- **@Bean 方法**：在配置类中声明 `@Bean`，相当于“工厂方法”，由 Spring 调用得到实例并纳入容器。

---

## 四、适用业务场景

- **同一抽象多种实现**：如多种支付方式、多种存储引擎，新增实现时只需新增工厂/产品类，不改调用方。
- **创建逻辑复杂**：对象需要多步初始化、依赖外部配置或策略时，集中到工厂方法中。
- **希望与具体类解耦**：调用方只依赖抽象产品与工厂接口，便于测试与替换实现。
- **与配置/策略结合**：根据配置或运行时条件选择不同产品实现（Spring 中常通过不同 Bean 定义或 Profile 实现）。

**不适用**：产品类型极少且几乎不变、创建逻辑极简单（直接 new 即可）的场景。

---

## 五、小结

工厂方法通过“抽象工厂 + 工厂方法”把对象创建延迟到子类，实现开闭原则；Spring 中 **BeanFactory / ApplicationContext** 与 **FactoryBean**、**@Bean** 都是工厂方法思想的体现。业务上适用于“多种实现选一种、创建逻辑集中、与具体类解耦”的场景。
