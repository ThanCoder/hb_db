# 1.2.0

## Breaking Changed

- Version 1.1.0 `[database].db` Not Working in Version 1.2.0.
- Added Database `version,databaseType`

## 1.1.0

- Fixed `Class Not Found`

## 1.0.0

## 📌 Introduction

HBDB is a **Hybrid Binary Database** for Dart/Flutter that allows you to store three main types of data inside a single ".db" file:

- **Map/JSON structured data** using Adapters
- **Binary files** (PDF, images, audio, any file)
- **Cover image (thumbnail)**

It uses a **custom binary format** with a **DB lock file**, supports **auto compact (clean-up)**, **stream reading**, **typed boxes**, and **listeners** for DB changes.

---

## 🚀 Features

- Type-safe data storage using **HBAdapter`<T>`**
- `add`, `update`, `delete`, `query`, `getAll`, `getAllStream`
- File entry support with compression
- Cover image support (set, get, delete)
- Auto compaction of database
- Built-in listeners for database and box-level events
- Single-file database design
