# Changelog

All notable changes are documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] – 2025-05-10

### Added
- Introduce fuzzy‐search support via Fuse.swift for matching within titles and notes  
- Provide fallback substring‐matching mode when fuzzy search is disabled  
- Initial database ORM integration with `sqlite-orm-swift`  
- Add `.gitignore` rule to ignore `Workflow/.build` directory  

### Changed
- Migrate database access from `sqlite-orm-swift` to [SQLite.swift](https://github.com/stephencelis/SQLite.swift)  
- Leverage Swift structured concurrency to parallelize lookup-map building and fuzzy searches  
- Bump macOS deployment target to v13 in `Package.swift`  
- Copy Things 3 database to a temporary file before querying to handle permission constraints  
- Restructure repository: remove legacy `Workflow` folder, Lua implementation, and outdated packaging scripts; consolidate sources and config into project root  
- Replace MIT license with GNU LGPL v3 (`LICENSE`); update `info.plist` (bundle ID, category, script-filter config, version → 1.0.0); overhaul `README.md` (features, usage, prerequisites, dependencies, license details)  

### Removed
- Legacy Lua workflow implementation, LuaJIT submodule and rockspec  
- Outdated build scripts (`justfile`, `package.sh`)  
- Old `LICENSE.txt` (MIT)  
- Unused Alfred JSON output fields: `score`, `matchedField`, `positions`  

### Fixed
- Ensure stale temporary database files are removed before copying to prevent permission conflicts and stale data  

---

[Unreleased]: https://github.com/philocalyst/AlfredThingsSearch/compare/v0.99.3...HEAD  
[1.0.0]:   https://github.com/philocalyst/AlfredThingsSearch/compare/v0.99.3...v1.0.0
