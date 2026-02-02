---
title: Python RecursiveCharacterTextSplitter 源码解析
date: 2025-01-30
---

# Python RecursiveCharacterTextSplitter 源码解析

## 概述

`RecursiveCharacterTextSplitter` 是 LangChain Python 中**推荐的通用文本分割器**。它按**分隔符优先级**递归切分文本，尽量保持段落、句子、词语的完整性，直到每个块满足 `chunk_size` 限制。

- 官方 API：[RecursiveCharacterTextSplitter](https://python.langchain.com/api_reference/text_splitters/character/langchain_text_splitters.character.RecursiveCharacterTextSplitter.html)

## 默认分隔符顺序

按优先级依次尝试，直到切出的块不超过 `chunk_size`：

| 优先级 | 分隔符 | 含义     |
|--------|--------|----------|
| 1      | `"\n\n"` | 段落     |
| 2      | `"\n"`   | 行       |
| 3      | `" "`    | 空格（词）|
| 4      | `""`     | 字符（兜底）|

即：先按段落切，超长再按行，再按空格，最后才按字符切。

## 核心参数

| 参数 | 类型 | 默认值 | 说明 | 来源 |
|------|------|--------|------|------|
| `chunk_size` | int | 1000 | 每个块的目标长度（字符数或 token 数） | **继承 TextSplitter** |
| `chunk_overlap` | int | 200 | 相邻块之间的重叠长度 | **继承 TextSplitter** |
| `length_function` | Callable | `len` | 计算长度的方式（字符数或 token 数） | **继承 TextSplitter** |
| `separators` | List[str] | `["\n\n", "\n", " ", ""]` | 分隔符列表，按顺序使用 | 本类 / CharacterTextSplitter |
| `keep_separator` | bool | True | 是否在切分后的文本中保留分隔符 | 本类 / CharacterTextSplitter |
| `is_separator_regex` | bool | False | 分隔符是否按正则解析 | 本类 / CharacterTextSplitter |

**继承自 TextSplitter 的参数**：`chunk_size`、`chunk_overlap`、`length_function`（基类定义块大小、重叠与长度计算方式；本类在此基础上增加 `separators`、`keep_separator`、`is_separator_regex` 等与分隔符相关的配置）。

## 源码解析

LangChain Python 的 `RecursiveCharacterTextSplitter` 继承自 `TextSplitter`，核心逻辑在**递归按分隔符切分**和**带重叠的合并**两处。

### 1. 递归切分：`_split_text`

按「当前分隔符」把文本拆成若干段；若某段仍超过 `chunk_size`，则用「下一个更细的分隔符」对该段递归切分。

```python
def _split_text(self, text: str, separators: List[str]) -> List[str]:
    if not text:
        return []
    # 无更多分隔符时，按字符兜底
    if not separators:
        return self._merge_splits(list(text), "")

    sep = separators[0]                    # 当前分隔符（如 "\n\n"）
    rest_separators = separators[1:]       # 更细的分隔符（如 "\n", " ", ""）
    splits = self._split_on_separator(text, sep)  # 按 sep 切分

    good_splits = []
    for s in splits:
        if self._length_function(s) <= self._chunk_size:
            good_splits.append(s)
        else:
            if good_splits:
                yield from self._merge_splits(good_splits, sep)
                good_splits = []
            if not rest_separators:
                yield from self._merge_splits([s], sep)
            else:
                yield from self._split_text(s, rest_separators)  # 递归
    if good_splits:
        yield from self._merge_splits(good_splits, sep)
```

要点：

- 用 `_split_on_separator(text, sep)` 得到当前层的 `splits`。
- 长度 ≤ `chunk_size` 的进入 `good_splits`，凑一批后 `_merge_splits` 合并并产出。
- 长度 > `chunk_size` 的：若还有 `rest_separators` 则递归 `_split_text(s, rest_separators)`；否则按当前层合并或按字符兜底。

### 2. 合并与重叠：`_merge_splits`

将一批小片段合并成若干块，每块长度约 `chunk_size`，相邻块之间重叠 `chunk_overlap`。

```python
def _merge_splits(self, splits: List[str], separator: str) -> List[str]:
    docs = []
    current = []
    total_len = 0
    sep_len = self._length_function(separator)

    for s in splits:
        n = self._length_function(s) + (sep_len if current else 0)
        if total_len + n > self._chunk_size and current:
            doc = self._join_docs(current, separator)
            docs.append(doc)
            # 重叠：从队头丢弃片段，使剩余长度约等于 chunk_overlap
            while current and (total_len > self._chunk_overlap or total_len + n > self._chunk_size):
                total_len -= self._length_function(current[0]) + (sep_len if len(current) > 1 else 0)
                current = current[1:]
            total_len = sum(self._length_function(x) for x in current) + sep_len * (len(current) - 1)
        current.append(s)
        total_len += n

    if current:
        docs.append(self._join_docs(current, separator))
    return docs
```

要点：

- 顺序遍历 `splits`，累加长度；超过 `chunk_size` 时先产出当前块，再根据 `chunk_overlap` 从队头丢弃片段，实现块间重叠。
- `_join_docs` 用 `separator` 把列表拼成最终字符串。

### 3. 调用链

| 入口方法 | 内部调用 |
|----------|----------|
| `split_text(text)` | `_split_text(text, self.separators)`，得到递归+合并后的块列表 |
| `split_documents(documents)` | 对每个 document 的 `page_content` 调 `split_text`，再按索引挂回 metadata |
| `create_documents(texts, metadatas)` | 对每个 `text` 调 `split_text`，用 `metadatas` 构造 Document |

## 常用方法

| 方法 | 说明 | 来源 |
|------|------|------|
| `split_text(text: str) -> List[str]` | 对单个字符串切分，返回字符串列表 | **继承 TextSplitter**（本类重写内部逻辑，仍调 `_split_text`） |
| `create_documents(texts: List[str], metadatas=None)` | 从字符串列表创建 Document 列表 | **继承 TextSplitter** |
| `split_documents(documents: List[Document]) -> List[Document]` | 对 Document 列表切分，保留元数据 | **继承 TextSplitter** |
| `transform_documents(documents: List[Document]) -> List[Document]` | 与 `split_documents` 等价，用于管道 | **继承 TextSplitter** |
| `from_tiktoken_encoder(...)` | 类方法，按 tiktoken 的 token 数切分 | 本类 / CharacterTextSplitter |
| `from_huggingface_tokenizer(...)` | 类方法，按 HuggingFace tokenizer 切分 | 本类 / CharacterTextSplitter |
| `from_language(language, ...)` | 类方法，按编程语言预设分隔符 | 本类 / CharacterTextSplitter |

**继承自 TextSplitter 的方法**：`split_text`、`create_documents`、`split_documents`、`transform_documents`（基类定义接口与默认实现，本类通过重写 `_split_text` 等改变切分行为）。

## 算法要点

1. **递归**：用当前分隔符切分；若有片段长度仍大于 `chunk_size`，则用下一个分隔符对该片段递归切分。
2. **重叠**：相邻块之间保留 `chunk_overlap` 个字符（或 token），避免语义在边界处断裂。
3. **长度计算**：默认用 `len()`（字符数）；通过 `length_function` 可改为 token 数（如 tiktoken）。
