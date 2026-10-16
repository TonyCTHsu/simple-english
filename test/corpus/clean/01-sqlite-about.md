SQLite is an in-process library that implements a self-contained, serverless,
zero-configuration, transactional SQL database engine. The code for SQLite is
in the public domain and is thus free for use for any purpose, commercial or
private. SQLite is the most widely deployed database in the world with more
applications than we can count, including several high-profile projects. <!-- se: ignore=SE_ING_AFTER_COMMA -->

SQLite is an embedded SQL database engine. Unlike most other SQL databases,
SQLite does not have a separate server process. SQLite reads and writes
directly to ordinary disk files. A complete SQL database with multiple
tables, indices, triggers, and views, is contained in a single disk file.
The database file format is cross-platform - you can freely copy a database
between 32-bit and 64-bit systems or between big-endian and little-endian
architectures. These features make SQLite a popular choice as an Application
File Format.

Think of SQLite not as a replacement for Oracle but as a replacement for
fopen(). SQLite is a compact library. With all features enabled, the library
size can be less than 900KiB, depending on the target platform and compiler <!-- se: ignore=SE_ING_AFTER_COMMA -->
optimization settings.
