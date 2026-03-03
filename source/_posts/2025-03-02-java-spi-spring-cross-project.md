---
title: SPI 机制与跨项目实现（含 Spring 与完整示例）
date: 2025-03-02
tags:
  - java
  - SPI
  - ServiceLoader
  - Spring
  - 自动配置
categories:
  - Java
  - Spring
---

# SPI 机制与跨项目实现（含 Spring 与完整示例）

本文说明 **SPI（Service Provider Interface）** 是什么、如何在**跨项目/多模块**下实现，以及如何与 **Spring** 结合使用，并给出可运行的示例（含目录结构）。

---

## 一、什么是 SPI

**SPI（Service Provider Interface）** 是“接口由一方定义，实现由多方提供，在运行时通过约定方式被发现与加载”的机制。

- **接口方**：定义标准接口（如 `javax.sql.Driver`、日志门面 API），不绑定具体实现。
- **实现方**：提供具体实现类，并按约定在 `META-INF/services/` 下声明“接口全限定名 → 实现类全限定名”。
- **使用方**：通过 **ServiceLoader** 或 **SpringFactoriesLoader** 加载当前 classpath 下所有实现，无需硬编码实现类名。

**典型用途**：驱动加载（JDBC、日志）、插件化、多实现可替换（如多种加密、多种序列化）。

---

## 二、Java 原生 SPI：ServiceLoader

### 2.1 约定

- 在 **META-INF/services/** 下新建文件，**文件名为接口的全限定类名**。
- 文件内容为**实现类的全限定类名**，一行一个；`#` 开头为注释。
- 实现类必须有**无参构造器**（ServiceLoader 通过反射实例化）。

### 2.2 使用方式

```java
ServiceLoader<MyService> loader = ServiceLoader.load(MyService.class);
for (MyService impl : loader) {
    impl.doSomething();
}
```

或：

```java
Iterator<MyService> it = ServiceLoader.load(MyService.class).iterator();
while (it.hasNext()) {
    MyService impl = it.next();
    // ...
}
```

**注意**：`ServiceLoader.load(Class, ClassLoader)` 使用传入的 ClassLoader（通常为当前线程上下文类加载器）加载实现类；跨项目时需保证接口与实现都在同一 classpath 或可被同一 ClassLoader 看到。

---

## 三、跨项目 / 多模块实现 SPI

### 3.1 模块划分

| 模块 | 职责 |
|------|------|
| **api** | 定义 SPI 接口（及可选常量、异常），供“使用方”和“实现方”依赖 |
| **impl-a / impl-b** | 实现接口，并在本模块 resources 下提供 `META-INF/services/接口全限定名` |
| **app** | 业务应用，依赖 api + 若干 impl 模块（或通过依赖传递/插件包引入），通过 ServiceLoader 加载实现 |

### 3.2 目录与文件示例

假设接口为 `com.example.spi.Greeter`，两个实现为 `com.example.impl.HelloGreeter` 和 `com.example.impl.HiGreeter`。

**api 模块**（只含接口）：

```text
api/
  src/main/java/com/example/spi/Greeter.java
```

```java
package com.example.spi;

public interface Greeter {
    String greet(String name);
}
```

**impl-a 模块**（实现 + 声明）：

```text
impl-a/
  src/main/java/com/example/impl/HelloGreeter.java
  src/main/resources/META-INF/services/com.example.spi.Greeter
```

`HelloGreeter.java`：

```java
package com.example.impl;

import com.example.spi.Greeter;

public class HelloGreeter implements Greeter {
    @Override
    public String greet(String name) {
        return "Hello, " + name;
    }
}
```

`META-INF/services/com.example.spi.Greeter` 文件内容（仅一行）：

```text
com.example.impl.HelloGreeter
```

**impl-b 模块**：同理，实现类如 `HiGreeter`，并在 `META-INF/services/com.example.spi.Greeter` 中写 `com.example.impl.HiGreeter`。

**app 模块**：依赖 api 以及需要启用的 impl-a / impl-b，主类中：

```java
ServiceLoader<Greeter> loader = ServiceLoader.load(Greeter.class);
loader.forEach(g -> System.out.println(g.greet("World")));
```

**依赖关系**：app 依赖 api + impl-a（或 impl-a、impl-b 都依赖）；**谁在 classpath 谁就会被 ServiceLoader 发现**。因此“跨项目”只需：接口在 api 工程，实现在各自工程并带好 `META-INF/services`，使用方工程通过 Maven/Gradle 依赖需要的实现模块即可。

---

## 四、Spring 中的 SPI 形态

### 4.1 SpringFactoriesLoader（spring.factories）

Spring 在 `spring-core` 中提供 **SpringFactoriesLoader**，约定从 **META-INF/spring.factories** 读取配置，格式为：

```properties
# key 为接口或抽象类全限定名，value 为实现类全限定名列表（逗号/换行分隔）
com.example.MyFactory=\
com.example.impl.MyFactoryImpl1,\
com.example.impl.MyFactoryImpl2
```

**加载方式**：

```java
List<MyFactory> list = SpringFactoriesLoader.loadFactories(MyFactory.class, classLoader);
```

常用于 **Spring Boot 自动配置**：key 为 `org.springframework.boot.autoconfigure.EnableAutoConfiguration`，value 为各 `@Configuration` / `@AutoConfiguration` 类。

### 4.2 Spring Boot 2.x 与 3.x 的差异

| 版本 | 自动配置声明位置 |
|------|------------------|
| **Spring Boot 2.x** | `META-INF/spring.factories`，key：`org.springframework.boot.autoconfigure.EnableAutoConfiguration` |
| **Spring Boot 3.x** | **META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports**，每行一个配置类全限定名 |

Boot 3 仍支持在 `spring.factories` 里写其他 key（如自定义 Factory），但 **EnableAutoConfiguration** 已改为从 `.imports` 读取。

**Boot 3 示例**（`META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`）：

```text
com.example.mystarter.MyAutoConfiguration
```

---

## 五、在 Spring 中集成 Java SPI 实现

若实现是通过 **Java SPI**（META-INF/services）提供的，可以在 Spring 里统一加载并注册为 Bean，供注入使用。

### 5.1 将 ServiceLoader 结果注册为 Bean

```java
@Configuration
public class SpiConfiguration {

    @Bean
    public List<Greeter> greeters() {
        List<Greeter> list = new ArrayList<>();
        ServiceLoader.load(Greeter.class).forEach(list::add);
        return list;
    }
}
```

业务代码中直接 `@Autowired List<Greeter> greeters` 使用即可。

### 5.2 按类型注入单个实现（当只有一个时）

若 classpath 下仅有一个 SPI 实现，可封装为单 Bean：

```java
@Configuration
public class SpiConfiguration {

    @Bean
    @ConditionalOnSingleCandidate(Greeter.class)
    public Greeter greeter() {
        return ServiceLoader.load(Greeter.class).findFirst()
            .orElseThrow(() -> new IllegalStateException("No Greeter implementation found"));
    }
}
```

### 5.3 与 Spring Boot Starter 结合

自定义 Starter 时，通常用 **Spring 的 SPI**（spring.factories 或 Boot 3 的 .imports）声明自动配置类；在自动配置类里再按需使用 **Java ServiceLoader** 加载你的 SPI 实现并注册为 Bean。例如：

```java
@AutoConfiguration
public class MyAutoConfiguration {

    @Bean
    public List<Greeter> greeters() {
        List<Greeter> list = new ArrayList<>();
        ServiceLoader.load(Greeter.class).forEach(list::add);
        return list;
    }
}
```

并在 `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` 中写上该类全限定名，这样引入你的 Starter 即可自动注册这些 Bean。

---

## 六、完整示例：三模块 + Spring Boot

### 6.1 项目结构（Maven）

```text
spi-demo/
  api/           # 接口
  impl-hello/   # 实现 Hello
  impl-hi/      # 实现 Hi
  app/          # Spring Boot 主应用，依赖 api + impl-hello + impl-hi
```

### 6.2 api 模块

**pom.xml**：仅需 `junit` 等（或无依赖）。

**Greeter.java**（同上）：

```java
package com.example.spi;

public interface Greeter {
    String greet(String name);
}
```

### 6.3 impl-hello 模块

- 依赖 **api**。
- **HelloGreeter.java** 实现 `Greeter`（同上）。
- **META-INF/services/com.example.spi.Greeter** 内容：`com.example.impl.HelloGreeter`（注意 impl-hello 里包名可为 `com.example.impl`，与 impl-hi 若同包则类名不可重复，如改为 `com.example.impl.hello.HelloGreeter` 更稳妥）。

### 6.4 impl-hi 模块

- 依赖 **api**。
- **HiGreeter.java**：`return "Hi, " + name;`
- **META-INF/services/com.example.spi.Greeter** 内容：`com.example.impl.HiGreeter`（或 `com.example.impl.hi.HiGreeter`）。

### 6.5 app 模块（Spring Boot）

**pom.xml**：依赖 `api`、`impl-hello`、`impl-hi` 以及 `spring-boot-starter`。

**SpiConfiguration.java**：

```java
package com.example.app;

import com.example.spi.Greeter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.ArrayList;
import java.util.List;
import java.util.ServiceLoader;

@Configuration
public class SpiConfiguration {

    @Bean
    public List<Greeter> greeters() {
        List<Greeter> list = new ArrayList<>();
        ServiceLoader.load(Greeter.class).forEach(list::add);
        return list;
    }
}
```

**AppRunner.java**（或 Controller）：

```java
package com.example.app;

import com.example.spi.Greeter;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class AppRunner implements CommandLineRunner {

    private final List<Greeter> greeters;

    public AppRunner(List<Greeter> greeters) {
        this.greeters = greeters;
    }

    @Override
    public void run(String... args) {
        greeters.forEach(g -> System.out.println(g.greet("SPI")));
    }
}
```

运行后控制台会输出两类问候（来自 HelloGreeter 与 HiGreeter），说明跨模块 SPI 已被 Spring 加载并注入。

---

## 七、小结

| 要点 | 说明 |
|------|------|
| **Java SPI** | 接口 + META-INF/services/接口全限定名 文件（内容为实现类全限定名），通过 **ServiceLoader** 加载 |
| **跨项目** | 接口放在 api 模块，各实现放在不同模块并各自提供 META-INF/services；使用方依赖 api 与需要的实现模块，classpath 中有谁就加载谁 |
| **Spring 的 SPI** | **SpringFactoriesLoader** + `spring.factories`；Boot 3 自动配置改用 **META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports** |
| **Spring 中用 Java SPI** | 在 `@Configuration` 里用 **ServiceLoader.load(接口)** 得到实现列表，注册为 List Bean 或单 Bean，即可 `@Autowired` 使用 |
| **Starter** | 自动配置类中可同时使用 Spring 的 SPI（声明配置类）和 Java SPI（加载业务实现并注册 Bean） |

按上述方式即可在跨项目场景下实现 SPI，并在 Spring / Spring Boot 中统一使用这些实现。
