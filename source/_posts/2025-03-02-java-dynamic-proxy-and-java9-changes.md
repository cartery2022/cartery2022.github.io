---
title: Java 动态代理原理与 Java 9+ 改动
date: 2025-03-02
tags:
  - java
  - 动态代理
  - 源码解读
categories:
  - Java
  - 源码解读
---

# Java 动态代理原理与 Java 9+ 改动

本文说明 **JDK 动态代理**（`java.lang.reflect.Proxy` + `InvocationHandler`）的原理、用法与限制，并单独梳理 **Java 9 及以后版本** 对动态代理的改动（模块化、代理类包与可见性、ProxyGenerator 位置等）。

---

## 一、什么是动态代理

**动态代理**：在运行时动态生成“代理类”的字节码并加载，由代理类把方法调用统一转交给一个 **InvocationHandler** 处理，从而在不改业务类的前提下做增强（日志、事务、权限等）。

JDK 自带的动态代理基于 **接口**：只能为“实现了若干接口”的目标生成代理，代理对象实现相同接口，方法调用最终进入 `InvocationHandler.invoke()`。

---

## 二、核心 API

### 2.1 Proxy

- **Proxy.newProxyInstance(ClassLoader loader, Class<?>[] interfaces, InvocationHandler h)**  
  在运行时生成并加载代理类，返回实现 `interfaces` 的代理实例，该实例上所有接口方法调用都会交给 `h` 处理。

### 2.2 InvocationHandler

- **Object invoke(Object proxy, Method method, Object[] args)**  
  代理实例上“对接口方法的调用”都会转发到这里。  
  - `proxy`：代理对象本身（不要用它在 handler 里再调接口方法，否则会递归进 handler）。  
  - `method`：被调用的方法。  
  - `args`：方法参数。  
  返回值作为该次方法调用的结果。

---

## 三、使用示例

```java
import java.lang.reflect.*;

interface Hello {
    String say(String name);
}

class HelloImpl implements Hello {
    @Override
    public String say(String name) {
        return "Hello, " + name;
    }
}

public class ProxyDemo {
    public static void main(String[] args) {
        Hello target = new HelloImpl();
        InvocationHandler handler = (proxy, method, args) -> {
            System.out.println("Before: " + method.getName());
            Object result = method.invoke(target, args);
            System.out.println("After: " + method.getName());
            return result;
        };

        Hello proxy = (Hello) Proxy.newProxyInstance(
            Hello.class.getClassLoader(),
            new Class<?>[]{Hello.class},
            handler
        );

        System.out.println(proxy.say("World"));
        // Before: say
        // After: say
        // Hello, World
    }
}
```

- 目标类必须 **实现接口**，代理的是“接口类型”，实际调用仍转发到 `target`。
- 若要对“没有接口的类”做代理，需用 **CGLIB** 等基于子类的方案，见后文对比。

---

## 四、工作原理（源码层面）

### 4.1 `Proxy.newProxyInstance` 源码主干（`java.lang.reflect.Proxy`）

入口完成**参数校验**（`interfaces` 非空、元素均为接口、类加载器一致等），再取得**代理类 `Class` 与构造器**，最后用 **`AccessController.doPrivileged`** 包一层**特权反射**，以 **`InvocationHandler` 为唯一入参** **`newInstance`** 出代理对象（JDK 版本间 `invoke` 无参构造 / `Constructor.newInstance` 细节略有整理，语义不变）。

```java
@CallerSensitive
public static Object newProxyInstance(ClassLoader loader,
                                      Class<?>[] interfaces,
                                      InvocationHandler h) {
    Objects.requireNonNull(h);
    final Class<?>[] intfs = interfaces.clone();
    // 安全与模块检查、生成或取缓存的代理类 Class clazz …
    try {
        Constructor<?> cons = clazz.getConstructor(InvocationHandler.class);
        return cons.newInstance(h);
    } catch (ReflectiveOperationException e) {
        throw new InternalError(e.toString(), e);
    }
}
```

**代理类从哪来**：**`Proxy.getProxyConstructor(loader, interfaces)`**（内部再 **`getProxyClass0`**）维护 **`loader + 接口签名 → Class`** 的**软引用缓存**；缓存未命中时由 **`ProxyGenerator.generateProxyClass`**（或同职责实现）生成字节码，再通过 **定义类 API**（历史上常见 **`Unsafe.defineClass` / `Lookup.defineHiddenClass`** 一类路径，随 JDK 演进）装入 **`loader`**。

### 4.2 生成的代理类长什么样

- 类名：通常为 **com.sun.proxy.$ProxyN**（N 为递增数字），Java 9+ 在模块化下可能处于“动态模块”，见第五节。
- **继承**：`extends java.lang.reflect.Proxy`（因此代理类也实现 `Serializable`）。
- **实现**：你传入的 `interfaces`。
- **字段**：从 Proxy 继承的 `protected InvocationHandler h`。
- **方法**：每个接口方法（以及从 Object 转发的 `equals`、`hashCode`、`toString`）内部都类似：

```java
public final String say(String name) {
    try {
        return (String) super.h.invoke(this, m_say, new Object[]{name});
    } catch (RuntimeException | Error e) {
        throw e;
    } catch (Throwable t) {
        throw new UndeclaredThrowableException(t);
    }
}
```

即：把调用转给 `InvocationHandler.invoke(proxy, method, args)`，检查异常后返回或包装为 `UndeclaredThrowableException`。

### 4.3 重要限制

- **只支持接口**：不能指定“代理某个类”，只能指定若干接口，代理类实现这些接口。
- **Object 方法**：`equals`、`hashCode`、`toString` 也会转发到 handler；其他 Object 方法（如 `getClass()`）不转发，由代理类自身实现。

---

## 五、知识点演变（自 Java 8 起按时间顺序）

JDK 动态代理早于 Java 8 已存在；本节从 **Java 8** 起按版本发布时间叙述，不向前追溯。

### 5.1 Java 8（基线）

- **公开 API**：**`Proxy.newProxyInstance`**、**`InvocationHandler.invoke`** 的用法与当今一致。
- **内部**：**`sun.misc.ProxyGenerator`**（非标准、不推荐依赖）；调试保存字节码可用 **`-Dsun.misc.ProxyGenerator.saveGeneratedFiles=true`**。

### 5.2 Java 9 及以后

- **JPMS**：代理类的 **包与模块可见性** 依赖接口所在包是否 **导出/打开**；若有接口在 **未导出且未打开** 的包中，代理类位于 **动态模块**，应用应通过 **`Proxy.newProxyInstance`** 创建，避免对代理类 **`Constructor.newInstance`** 反射失败（**`IllegalAccessException`**）。

| 情况 | 代理类所在位置/可见性 |
|------|------------------------|
| 所有代理接口都在**已导出或已打开**的包中 | 代理类在约定实现包（如 com.sun.proxy），公共接口时一般为 public |
| 至少一个代理接口在**未导出且未打开**的包中 | 代理类在 **动态模块**；须用 **Proxy.newProxyInstance()** |

- **ProxyGenerator** 迁至 **jdk.internal** 等非导出路径；保存生成类改用 **`-Djdk.proxy.ProxyGenerator.saveGeneratedFiles=true`**。

### 5.3 小结表

| 顺序 | 版本 | 要点 |
|------|------|------|
| ① | **Java 8** | API 定型；sun.misc 调试开关 |
| ② | **Java 9+** | 模块与动态模块；内部迁移与新调试属性 |

**对外**：**`Proxy.newProxyInstance`** / **`InvocationHandler`** 的签名与语义不变。

---

## 六、与 CGLIB 的简要对比

| 对比项 | JDK 动态代理 | CGLIB |
|--------|--------------|--------|
| **代理对象** | 实现指定接口 | 继承目标类（子类） |
| **前提** | 必须有接口 | 无接口也可，目标类/方法不能为 final |
| **实现方式** | 反射 + 运行时生成实现接口的类 | ASM 等字节码生成子类 |
| **典型用法** | Spring 中“Bean 实现了接口”时的默认代理 | Spring 中“Bean 无接口”或 `proxy-target-class=true` |

需要代理“没有接口的类”或“类上的方法”时，只能用 CGLIB（或类似字节码方案），不能用 JDK Proxy。

---

## 七、小结

- **JDK 动态代理**：通过 **Proxy.newProxyInstance** 传入类加载器、接口数组和 **InvocationHandler**，在运行时生成实现这些接口的代理类，所有接口方法（以及 equals/hashCode/toString）调用都转到 **handler.invoke**，常用于 AOP、RPC 客户端等。
- **限制**：只能基于接口；代理类继承 `Proxy`，由内部 ProxyGenerator 生成字节码并加载。
- **演变**：自 **Java 8** 基线到 **Java 9+** 的模块、动态模块与 **ProxyGenerator** 内部迁移；保存字节码改用 **`jdk.proxy.ProxyGenerator.saveGeneratedFiles`**；**对外 API 不变**。
