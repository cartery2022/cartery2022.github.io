---
title: 设计模式（四）建造者模式 — 详解、Spring 运用与业务场景
date: 2025-03-02
tags:
  - 设计模式
  - 建造者
  - Builder
  - Spring
categories:
  - 设计模式
  - 创建型
---

# 建造者模式（Builder）

## 一、模式概述

**建造者模式**将复杂对象的构建与表示分离，使同样的构建过程可以创建不同的表示。

**解决的问题**：对象有很多可选参数或构造步骤复杂，若用多参构造或大量 setter，可读性差且易出错；建造者通过链式调用、分步设置，使构建过程清晰并可校验。

**定义**：将一个复杂对象的构建与它的表示分离，使得同样的构建过程可以创建不同的表示。

---

## 二、结构与角色

- **Product**：被构建的复杂对象。
- **Builder**：抽象建造者，定义构建步骤的接口。
- **ConcreteBuilder**：具体建造者，实现各步骤并持有 Product。
- **Director**（可选）：指挥者，按固定顺序调用 Builder 的步骤；有时由调用方直接使用 Builder，无 Director。

**示例**：

```java
public class Resource {
    private final String url;
    private final int timeout;
    private final Map<String, String> headers;
    private Resource(Builder b) {
        this.url = b.url;
        this.timeout = b.timeout;
        this.headers = b.headers;
    }
    public static class Builder {
        private String url;
        private int timeout = 5000;
        private Map<String, String> headers = new HashMap<>();
        public Builder url(String url) { this.url = url; return this; }
        public Builder timeout(int t) { this.timeout = t; return this; }
        public Builder header(String k, String v) { this.headers.put(k, v); return this; }
        public Resource build() {
            if (url == null) throw new IllegalStateException("url required");
            return new Resource(this);
        }
    }
}
// 使用: new Resource.Builder().url("http://a.com").timeout(3000).build();
```

---

## 三、在 Spring 中的运用

- **XML/配置的解析与构建**：如解析 XML 生成 BeanDefinition、构建 Environment 等，内部常按步骤组装复杂对象，具有建造者思想。
- **RestTemplate.Builder、WebClient.Builder**：Spring Web 提供的 Builder API，链式设置 URL、头、超时等再 `build()` 出客户端实例。
- **Spring Boot 的 *Properties 与 *AutoConfiguration**：部分配置类通过 Builder 或类似“分步设置 + build”的方式组装（如某些 Security、Actuator 配置）。

---

## 四、适用业务场景

- **参数多且多可选**：如创建请求/连接/查询条件，参数超过 4～5 个且多数有默认值时，Builder 比多参构造和满屏 setter 更清晰。
- **构建过程需校验**：在 `build()` 中统一校验必填项、约束，避免生成无效对象。
- **不可变对象**：配合 final 字段 + 私有构造，只通过 Builder 构造，保证创建后不可被随意修改。
- **多种“套餐”配置**：同一类对象有多种常用组合（如“高可用套餐”“开发套餐”），可在 Builder 上封装 preset 方法。

**不适用**：对象很简单、参数很少且必填时，直接构造或工厂方法即可。

---

## 五、小结

建造者模式通过“分步设置 + build 校验”降低复杂对象构建的出错率并提升可读性；Spring 中在**配置解析、RestTemplate/WebClient.Builder** 等处有体现。业务上适用于**多可选参数、需校验、不可变对象、多种预设配置**的构建场景。
