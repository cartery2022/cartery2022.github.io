---
title: 设计模式（三）抽象工厂模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 抽象工厂
  - Spring
categories:
  - 设计模式
  - 创建型
---

# 抽象工厂模式（Abstract Factory）

## 一、模式概述

**抽象工厂模式**提供一个创建一系列相关或相互依赖对象的接口，无需指定具体类。

**解决的问题**：当需要一组“配套”的产品（如 UI 主题：按钮+文本框+边框 为一族），且可能有多套实现（主题 A、主题 B）时，保证同一族产品一起创建、不混用。

**与工厂方法的区别**：工厂方法针对“一个产品”；抽象工厂针对“一族产品”，一个工厂接口可创建多个产品类型。

---

## 二、结构与角色

- **AbstractFactory**：抽象工厂，声明创建一族产品的多个方法（如 createButton、createTextBox）。
- **ConcreteFactory**：具体工厂，实现一族产品的创建（如 WinFactory 创建 WinButton + WinTextBox）。
- **AbstractProduct A/B**：各产品类型的抽象。
- **ConcreteProduct**：各产品类型的具体实现。

**示例**：

```java
interface Button { void render(); }
interface TextBox { void input(); }
class WinButton implements Button { public void render() {} }
class WinTextBox implements TextBox { public void input() {} }

interface GUIFactory {
    Button createButton();
    TextBox createTextBox();
}
class WinFactory implements GUIFactory {
    public Button createButton() { return new WinButton(); }
    public TextBox createTextBox() { return new WinTextBox(); }
}
```

---

## 三、在 Spring 中的运用

- **BeanFactory 作为“工厂的工厂”**：可生产多种类型的 Bean（Service、Repository、DataSource 等），不同配置/Profile 对应不同“族”的实现（如 dev 用 H2、prod 用 MySQL），相当于多套具体工厂。
- **LocalContainerEntityManagerFactoryBean / 数据源与事务管理器**：JPA、数据源、事务管理器往往“一族”一起配置，由不同配置类或 Profile 提供不同“族”的实现。
- **多数据源、多消息中间件**：同一应用内多套“连接工厂 + 相关 Bean”，每套可视为一个抽象工厂实现。

---

## 四、适用业务场景

- **多套“产品族”可替换**：如多租户下每租户一套数据源+缓存+配置，或多环境（dev/test/prod）各一套基础设施。
- **UI 主题、跨平台 UI**：同一套控件接口，多套外观实现（Windows/Mac/Linux 风格）。
- **兼容多版本外部系统**：如对接支付/消息的 v1、v2 两套 API，每套是一族（Client + Parser + Mapper），通过抽象工厂切换。
- **平台相关实现**：如不同操作系统、不同运行时提供不同底层实现，对外统一接口，内部按平台选工厂。

**不适用**：产品族概念不强、只有单一产品类型或产品之间无“配套”关系时，用工厂方法或简单工厂即可。

---

## 五、小结

抽象工厂通过“一族产品由一个工厂创建”保证产品配套、便于整体切换；Spring 中 **BeanFactory 体系**与**多数据源/多环境配置**体现了这一思想。业务上适用于“多套可替换产品族、主题/平台/多租户”等场景。
