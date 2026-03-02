---
title: 设计模式（二十二）模板方法模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 模板方法
  - Spring
categories:
  - 设计模式
  - 行为型
---

# 模板方法模式（Template Method）

## 一、模式概述

**模板方法模式**在抽象类中定义算法的骨架，将某些步骤延迟到子类；子类在不改变算法结构的前提下可重写特定步骤。

**解决的问题**：多个类有相同流程（如“打开连接 → 执行 → 关闭连接”），只有少数步骤不同；把相同流程放在父类模板方法中，不同步骤抽象为钩子方法由子类实现，避免重复代码。

**定义**：在方法中定义算法的骨架，而将一些步骤延迟到子类；模板方法使子类可以在不改变算法结构的情况下重新定义算法的某些步骤。

---

## 二、结构与角色

- **AbstractClass**：抽象类，定义模板方法（如 templateMethod()），内部按顺序调用抽象方法或钩子方法；部分步骤可有默认实现。
- **ConcreteClass**：具体子类，实现抽象方法或覆盖钩子方法，完成特定步骤的具体逻辑。

**示例**：

```java
abstract class AbstractClass {
    public final void templateMethod() {
        step1();
        step2();  // 子类实现
        step3();
    }
    private void step1() { System.out.println("step1"); }
    abstract void step2();
    private void step3() { System.out.println("step3"); }
}
class ConcreteClass extends AbstractClass {
    void step2() { System.out.println("custom step2"); }
}
```

---

## 三、在 Spring 中的运用

- **JdbcTemplate**：`query/update` 等方法是模板方法，内部固定“获取连接、创建语句、执行、处理结果集、关闭资源”，把“如何设置参数、如何映射结果”通过回调（RowMapper、PreparedStatementCreator 等）交给调用方，是典型的“模板 + 回调”结合。
- **RestTemplate**：请求流程固定（构建请求、发送、处理响应），具体 URL、头、解析方式由调用方传入，模板方法思想。
- **AbstractController / 各类 *Template**：许多抽象基类定义 doGet/doPost 或 execute 模板，子类或回调填充具体步骤。
- **Bean 的初始化/销毁**：InitializingBean.afterPropertiesSet()、DisposableBean.destroy() 可视为“生命周期模板”中的钩子，子类实现以插入自定义逻辑。
- **JpaDaoSupport / HibernateDaoSupport**（传统用法）：父类提供 getSessionFactory、getHibernateTemplate 等模板式封装，子类专注业务方法。

---

## 四、适用业务场景

- **固定流程、可变步骤**：如“校验 → 查库 → 计算 → 落库 → 发消息”，其中“计算”“发消息”等由业务子类或策略实现，其余流程统一在模板中。
- **复用公共骨架**：如“打开资源 → 处理 → 关闭资源”“开启事务 → 执行业务 → 提交/回滚”，骨架在基类，差异在子类。
- **框架/基类设计**：框架定义“请求处理流程”“任务执行流程”，用户通过重写钩子或实现回调插入逻辑，而不改流程顺序。
- **测试**：模板方法便于用子类或匿名类只重写待测步骤，其余用默认实现，方便单测。

**不适用**：流程中每步都差异很大、几乎没有公共骨架时，用组合+策略更合适。

---

## 五、小结

模板方法模式通过“抽象类定义模板方法 + 子类实现钩子”复用算法骨架；Spring 中 **JdbcTemplate**、**RestTemplate**、**各类 *Template 与抽象基类**、**生命周期钩子** 是典型应用。业务上适用于**固定流程可变步骤、资源/事务骨架、框架扩展点**等场景。
