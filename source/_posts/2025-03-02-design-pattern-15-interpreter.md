---
title: 设计模式（十五）解释器模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 解释器
  - Spring
categories:
  - 设计模式
  - 行为型
---

# 解释器模式（Interpreter）

## 一、模式概述

**解释器模式**给定一门语言（或表达式）的表示与解释方式，用解释器解释句子（或表达式）并执行。

**解决的问题**：当存在一种“小语言”（如表达式、简单脚本、规则描述），需要解析并执行时，用解释器把语法拆成若干类，每类负责一种语法单元的解析与求值。

**定义**：给定一个语言，定义它的文法的一种表示，并定义一个解释器，用该解释器解释语言中的句子。

---

## 二、结构与角色

- **AbstractExpression**：抽象表达式，声明 interpret(Context) 接口。
- **TerminalExpression**：终结符表达式，对应文法中的终结符（如常量、变量）。
- **NonterminalExpression**：非终结符表达式，对应文法中的规则，内部包含多个子表达式并组合求值。
- **Context**：上下文，存放变量、输入等，供解释过程使用。

**示例**（简单加减法）：

```java
interface Expr {
    int interpret(Map<String, Integer> ctx);
}
class Number implements Expr {
    private final int value;
    Number(int value) { this.value = value; }
    public int interpret(Map<String, Integer> ctx) { return value; }
}
class Add implements Expr {
    private final Expr left, right;
    Add(Expr l, Expr r) { left = l; right = r; }
    public int interpret(Map<String, Integer> ctx) {
        return left.interpret(ctx) + right.interpret(ctx);
    }
}
```

---

## 三、在 Spring 中的运用

- **SpEL（Spring Expression Language）**：Spring 的表达式语言，用于 @Value、@ConditionalOnExpression、缓存 key、安全表达式等；内部将表达式解析成 AST 并解释执行，是典型的解释器模式。
- **ExpressionParser 与 Expression**：`ExpressionParser.parseExpression(expr)` 得到 `Expression`，再 `getValue(context)` 求值，对应“解析 + 解释”。
- **条件注解中的表达式**：如 `@ConditionalOnExpression("...")`，字符串被解析并求值，决定是否加载 Bean。
- **简单规则引擎**：若业务中用“规则字符串”描述条件（如 "age > 18 && city == 'Beijing'"），可用解释器或 SpEL 解析并求值。

---

## 四、适用业务场景

- **配置/脚本中的表达式**：如配置里写 `"${env}-${version}"`、简单运算或条件，需要解析并求值。
- **规则/策略的文本描述**：如风控规则“金额>10000 且 次数>5”，用小型 DSL 描述并由解释器执行。
- **查询/过滤条件**：用户输入简单条件表达式，解析后生成过滤逻辑或 SQL 条件（需防注入）。
- **公式计算**：如报表中的单元格公式、定价公式，用表达式描述并由解释器求值。

**不适用**：语法复杂、性能要求高时，应使用 parser generator 或预编译；简单固定格式用正则或手写解析即可。

---

## 五、小结

解释器模式通过“为语法中的每种符号定义解释类 + 组合求值”实现小语言的解析与执行；Spring 中 **SpEL**、**ExpressionParser/Expression**、**条件表达式** 是典型应用。业务上适用于**配置表达式、规则描述、简单公式/条件**等场景。
