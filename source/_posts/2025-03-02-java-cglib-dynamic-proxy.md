---
title: CGLIB 动态代理原理与使用
date: 2025-03-02
tags:
  - java
  - CGLIB
  - 动态代理
  - Enhancer
  - MethodInterceptor
categories:
  - Java
  - 源码解读
---

# CGLIB 动态代理原理与使用

本文介绍 **CGLIB**（Code Generation Library）动态代理：与 JDK 动态代理的差异、核心 API（Enhancer、MethodInterceptor）、使用示例、实现原理与限制，并简要说明在 Spring AOP 中的使用方式。

---

## 一、CGLIB 与 JDK 动态代理的差异

| 对比项 | JDK 动态代理 | CGLIB 动态代理 |
|--------|--------------|----------------|
| **代理方式** | 实现与目标相同的**接口**，委托给 InvocationHandler | 生成目标类的**子类**，重写非 final 方法 |
| **前提** | 目标必须实现接口 | 目标为**普通类**即可，不能是 final 类 |
| **实现手段** | 反射 + Proxy 生成实现接口的类 | **ASM** 字节码生成子类 |
| **方法调用** | 反射 Method.invoke | 子类重写方法内调用 **MethodProxy.invokeSuper**（或反射） |
| **典型场景** | 有接口的 Bean、RPC 客户端 | 无接口的 Bean、对类方法做 AOP |

**一句话**：JDK Proxy 是“实现同一接口的代理”；CGLIB 是“继承目标类，用子类做代理”。

---

## 二、核心 API

### 2.1 Enhancer

- **Enhancer** 是 CGLIB 里用来生成“代理子类”的入口。
- 常用步骤：
  - **setSuperclass(Class)**：指定要继承的目标类（被代理类）。
  - **setCallback(Callback)**：设置方法拦截逻辑，一般用 **MethodInterceptor**。
  - **create()**：无参时生成代理实例（会调用目标类无参构造）；**create(Class[], Object[])**：指定构造器参数类型与实参。

### 2.2 MethodInterceptor

- **Callback** 的子接口，最常用的拦截器。
- 方法：**Object intercept(Object obj, Method method, Object[] args, MethodProxy proxy)**
  - **obj**：CGLIB 生成的代理对象（子类实例）。
  - **method**：被拦截的方法（目标类上的方法）。
  - **args**：方法参数。
  - **proxy**：**MethodProxy**，用于调用“父类（目标类）的原始方法”，避免反射，性能更好。
- 调用 **proxy.invokeSuper(obj, args)** 即执行“目标类上的该方法”，返回值即原方法返回值。

### 2.3 其他 Callback 类型

- **NoOp.INSTANCE**：不增强，直接调用父类实现，常用于 **CallbackFilter** 中“某些方法不拦截”。
- **FixedValue**：不执行原方法，每次返回 **loadObject()** 的固定值，需与返回类型兼容。
- **CallbackFilter**：按 **Method** 返回不同 Callback 数组下标，实现“按方法选择不同拦截逻辑”。

---

## 三、基本使用示例

**依赖**（Maven 示例，CGLIB 独立库）：

```xml
<dependency>
    <groupId>cglib</groupId>
    <artifactId>cglib</artifactId>
    <version>3.3.0</version>
</dependency>
```

**目标类（无接口）**：

```java
public class UserService {
    public String login(String username) {
        return "User " + username + " logged in.";
    }

    public void logout() {
        System.out.println("logout");
    }
}
```

**创建 CGLIB 代理**：

```java
import net.sf.cglib.proxy.*;

public class CglibProxyDemo {
    public static void main(String[] args) {
        Enhancer enhancer = new Enhancer();
        enhancer.setSuperclass(UserService.class);
        enhancer.setCallback((MethodInterceptor) (obj, method, args, proxy) -> {
            System.out.println("Before: " + method.getName());
            Object result = proxy.invokeSuper(obj, args);  // 调用目标类方法
            System.out.println("After: " + method.getName());
            return result;
        });

        // 无参 create() 会走目标类无参构造
        UserService proxy = (UserService) enhancer.create();
        System.out.println(proxy.login("Alice"));
        proxy.logout();
    }
}
```

输出示例：

```
Before: login
After: login
User Alice logged in.
Before: logout
logout
After: logout
```

- 若目标类**没有无参构造**，需用 **enhancer.create(Class[] parameterTypes, Object[] args)** 指定有参构造的类型与实参。
- 在 **intercept** 里不要用 **method.invoke(obj, args)** 调用“当前方法”，会再次进入拦截器造成递归；应使用 **proxy.invokeSuper(obj, args)** 调用父类（目标类）实现。

---

## 四、实现原理简述

1. **字节码生成**：CGLIB 使用 **ASM** 在内存中生成目标类的子类字节码，子类重写目标类中所有 **非 final** 的 public/protected 方法。
2. **方法体**：重写后的方法体内不直接写业务逻辑，而是调用 **Callback**（如 MethodInterceptor）的 **intercept**，并把 **MethodProxy** 传进去。
3. **MethodProxy**：内部使用 **FastClass** 机制（为类生成下标索引，按索引调用方法），避免每次反射 **Method.invoke**，因此多次调用时往往比纯反射更快。
4. **加载**：生成的字节码通过 **ClassLoader.defineClass** 或类似方式加载，再通过反射取构造器并 **newInstance** 得到代理实例。

因此 CGLIB 代理对象在运行时是“目标类的子类”，`proxy instanceof UserService` 为 true。

---

## 五、限制与注意点

### 5.1 final 类与 final 方法

- **final 类**：不能被继承，CGLIB 无法生成子类，无法代理。
- **final 方法**：不能被子类重写，CGLIB 无法拦截，调用时直接走目标类实现。

### 5.2 构造器

- **create()** 无参时，会调用目标类的 **无参构造器**。若目标类没有无参构造器，需使用 **create(Class[] parameterTypes, Object[] args)** 指定可访问的构造器及参数。
- 目标类若只有 **private 构造器**，子类无法在其构造器里调用 `super(...)`，会报错（如 IllegalAccessError），这类类无法用 CGLIB 代理。

### 5.3 与 JDK Proxy 的选用

- 有**接口**且只需代理接口方法 → 优先 **JDK 动态代理**（无额外依赖、与模块化兼容更好）。
- **无接口**或需要代理“类上的方法” → 使用 **CGLIB**（或 Spring 封装后的 CGLIB）。

---

## 六、在 Spring AOP 中的使用

- Spring AOP 在对 **Bean** 做代理时：
  - 若 Bean **实现了接口**且未强制指定“按类代理”，默认用 **JDK 动态代理**（基于接口）。
  - 若 Bean **没有实现接口**，或配置了 **proxy-target-class=true**，则使用 **CGLIB** 生成目标类的子类代理。
- Spring 自带的 CGLIB 相关类在 **spring-core** 中（如 `org.springframework.cglib.proxy.Enhancer`），多数场景无需单独引入 cglib 依赖；高版本 Spring 可能使用 repackage 后的 CGLIB 或其它字节码方案，但用法概念一致：基于子类、MethodInterceptor、invokeSuper。

---

## 七、小结

- **CGLIB** 通过 **Enhancer** 指定 **setSuperclass** 和 **setCallback(MethodInterceptor)**，在运行时生成目标类的**子类**，重写非 final 方法并在方法内转交 **intercept**，通过 **MethodProxy.invokeSuper** 调用原始逻辑。
- **特点**：可代理“无接口的类”，基于 ASM/FastClass，适合对类方法做 AOP；**限制**：不能代理 final 类/方法，目标类需有可被调用的构造器（通常为无参）。
- 与 **JDK 动态代理** 互补：有接口用 JDK Proxy，无接口或需代理类方法用 CGLIB；Spring AOP 会根据 Bean 是否有接口及配置自动选择二者之一。
