# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Refactored code structure to eliminate duplication across platform scripts
- Extracted common Python logic into `src/worthit_core.py` (265 lines)
- Reduced total codebase from 912 to 412 lines (55% reduction)
- Updated `install.sh` to download both platform script and core module

### Improved
- Maintainability: Pricing updates now require changes in only one file
- Code organization: Clear separation between business logic and platform-specific notification code

## [1.0.0] - 2025-01-25

### Added
- Initial release with multi-platform support (Linux, macOS, Windows/WSL)
- Real-time token usage and cost tracking via native notifications
- Support for Claude Opus 4.5, Sonnet 4.5, and Haiku 4.5 models
- Zero external dependencies (Python standard library only)
- Comprehensive security features:
  - 4-layer defense-in-depth architecture
  - Input validation and sanitization
  - Path traversal attack prevention
  - Command injection protection
- Complete documentation:
  - README.md with installation and usage instructions
  - SECURITY.md with security architecture and audit history
  - PRICING.md with transparent pricing information
  - MANUAL_INSTALL.md for advanced users
- Comprehensive test suite:
  - 33 unit tests (sanitization, pricing)
  - 14 integration tests (E2E scenarios)
  - Security attack simulation tests
- CI/CD with GitHub Actions (8 workflows)
- One-line installation script (`install.sh`)

### Fixed
- Output token estimation workaround for Claude CLI transcript bug
  - Claude CLI records 1-2 tokens instead of actual 100s of tokens
  - Implemented custom estimation algorithm based on content length

### Security
- Conducted comprehensive security audit (2025-01-25)
- Fixed 4 Critical/High severity vulnerabilities:
  - Path traversal attacks
  - Command injection via shell metacharacters
  - Variable expansion exploits
  - Shell escaping vulnerabilities
- All security fixes verified through integration tests

## [0.9.0] - 2025-01-23 (Beta)

### Added
- Beta release for testing
- Core functionality implementation
- Basic platform support

---

## Version Guidelines

### Types of Changes
- **Added**: New features
- **Changed**: Changes in existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Vulnerability fixes or security improvements

### Version Numbering
- **Major** (X.0.0): Incompatible API changes or major redesign
- **Minor** (0.X.0): New features in a backward-compatible manner
- **Patch** (0.0.X): Backward-compatible bug fixes

---

[unreleased]: https://github.com/dukbong/worthit/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/dukbong/worthit/releases/tag/v1.0.0
[0.9.0]: https://github.com/dukbong/worthit/releases/tag/v0.9.0
