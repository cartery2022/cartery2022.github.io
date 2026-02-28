---
title: Python RecursiveCharacterTextSplitter — Source Walkthrough
date: 2025-01-30
tags:
  - agent
  - python
  - langchain
  - source-reading
categories:
  - agent
  - source-reading
  - textSplitter
---

# Python RecursiveCharacterTextSplitter — Source Walkthrough

## Overview

`RecursiveCharacterTextSplitter` is the **recommended general-purpose text splitter** in LangChain Python. It recursively splits text by **separator priority**, trying to keep paragraphs, lines, and words intact until each chunk fits within the `chunk_size` limit.

- API reference: [RecursiveCharacterTextSplitter](https://python.langchain.com/api_reference/text_splitters/character/langchain_text_splitters.character.RecursiveCharacterTextSplitter.html)

## Default separator order

Separators are tried in order until the resulting chunks do not exceed `chunk_size`:

| Priority | Separator | Meaning        |
|----------|-----------|----------------|
| 1        | `"\n\n"`  | Paragraph      |
| 2        | `"\n"`    | Line           |
| 3        | `" "`     | Space (word)   |
| 4        | `""`      | Character (fallback) |

So it first splits by paragraph, then by line if still too long, then by space, and finally by character.

## Main parameters

| Parameter           | Type      | Default                        | Description                                              | Source                    |
|---------------------|-----------|--------------------------------|----------------------------------------------------------|---------------------------|
| `chunk_size`        | int       | 1000                           | Target length per chunk (chars or tokens)                | **TextSplitter**          |
| `chunk_overlap`     | int       | 200                            | Overlap between adjacent chunks                         | **TextSplitter**          |
| `length_function`   | Callable  | `len`                          | How to measure length (chars or tokens)                  | **TextSplitter**          |
| `separators`        | List[str] | `["\n\n", "\n", " ", ""]`      | Separator list, used in order                            | This class / CharacterTextSplitter |
| `keep_separator`    | bool      | True                           | Whether to keep the separator in split text             | This class / CharacterTextSplitter |
| `is_separator_regex`| bool      | False                          | Whether separators are treated as regex                  | This class / CharacterTextSplitter |

**From TextSplitter**: `chunk_size`, `chunk_overlap`, `length_function`. This class adds separator-related options: `separators`, `keep_separator`, `is_separator_regex`.

## Source walkthrough

LangChain Python’s `RecursiveCharacterTextSplitter` extends `TextSplitter`. The core logic is **recursive splitting by separators** and **merging with overlap**.

### 1. Recursive split: `_split_text`

Split text by the “current” separator; if a segment still exceeds `chunk_size`, recursively split it with the “next finer” separator.

```python
def _split_text(self, text: str, separators: List[str]) -> List[str]:
    if not text:
        return []
    # No more separators: fallback to character split
    if not separators:
        return self._merge_splits(list(text), "")

    sep = separators[0]                    # Current separator (e.g. "\n\n")
    rest_separators = separators[1:]       # Finer separators (e.g. "\n", " ", "")
    splits = self._split_on_separator(text, sep)  # Split by sep

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
                yield from self._split_text(s, rest_separators)  # Recurse
    if good_splits:
        yield from self._merge_splits(good_splits, sep)
```

Notes:

- `_split_on_separator(text, sep)` produces the current-level `splits`.
- Segments with length ≤ `chunk_size` go into `good_splits`, then get merged with `_merge_splits` and yielded.
- Segments longer than `chunk_size`: if `rest_separators` is non-empty, recurse with `_split_text(s, rest_separators)`; otherwise merge at current level or fall back to character split.

### 2. Merge and overlap: `_merge_splits`

Merge a batch of small segments into chunks of about `chunk_size`, with `chunk_overlap` between adjacent chunks.

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
            # Overlap: drop from the front until remaining length ≈ chunk_overlap
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

Notes:

- Iterate over `splits`, accumulate length; when over `chunk_size`, emit the current chunk, then trim from the front according to `chunk_overlap` to get overlap.
- `_join_docs` joins the list with `separator` into the final string.

### 3. Call chain

| Entry method | Internal call |
|--------------|----------------|
| `split_text(text)` | `_split_text(text, self.separators)` → list of chunks after recursive split + merge |
| `split_documents(documents)` | For each document’s `page_content`, call `split_text`, then reattach metadata by index |
| `create_documents(texts, metadatas)` | For each `text`, call `split_text`, build Document with `metadatas` |

## Common methods

| Method | Description | Source |
|--------|-------------|--------|
| `split_text(text: str) -> List[str]` | Split a single string; return list of strings | **TextSplitter** (this class overrides internals, still uses `_split_text`) |
| `create_documents(texts: List[str], metadatas=None)` | Create list of Documents from list of strings | **TextSplitter** |
| `split_documents(documents: List[Document]) -> List[Document]` | Split list of Documents, keep metadata | **TextSplitter** |
| `transform_documents(documents: List[Document]) -> List[Document]` | Same as `split_documents`, for pipelines | **TextSplitter** |
| `from_tiktoken_encoder(...)` | Class method: split by tiktoken token count | This class / CharacterTextSplitter |
| `from_huggingface_tokenizer(...)` | Class method: split by HuggingFace tokenizer | This class / CharacterTextSplitter |
| `from_language(language, ...)` | Class method: language-specific separator presets | This class / CharacterTextSplitter |

**From TextSplitter**: `split_text`, `create_documents`, `split_documents`, `transform_documents`. This class changes behavior by overriding `_split_text` and related logic.

## Algorithm summary

1. **Recursion**: Split with the current separator; if any segment is still longer than `chunk_size`, recursively split it with the next separator.
2. **Overlap**: Keep `chunk_overlap` characters (or tokens) between adjacent chunks to avoid cutting semantics at boundaries.
3. **Length**: Default is `len()` (character count); `length_function` can be set to token count (e.g. tiktoken).
