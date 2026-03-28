---
phase: 04
slug: parser
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-28
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Hand-rolled (deftest/assert-equal/assert-true/assert-signals) |
| **Config file** | tests/test-framework.lisp |
| **Quick run command** | `bash run-tests.sh` |
| **Full suite command** | `bash run-tests.sh` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash run-tests.sh`
- **After every plan wave:** Run `bash run-tests.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 2 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | PAR-22 (infra) | unit | `bash run-tests.sh` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | PAR-01,02,03 | unit | `bash run-tests.sh` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 2 | PAR-04,05,06,07,08,09,10 | unit | `bash run-tests.sh` | ❌ W0 | ⬜ pending |
| 04-02-02 | 02 | 2 | PAR-11,12,13,14,15,16,17 | unit | `bash run-tests.sh` | ❌ W0 | ⬜ pending |
| 04-03-01 | 03 | 3 | PAR-18,19,20,21 | unit | `bash run-tests.sh` | ❌ W0 | ⬜ pending |
| 04-03-02 | 03 | 3 | PAR-01-21 (integration) | integration | `bash run-tests.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test-parser.lisp` — test file with `innate.tests.parser` package
- [ ] `tests/packages.lisp` — add `innate.tests.parser` package definition
- [ ] `innatescript.asd` — add `test-parser` component to test system
- [ ] `src/packages.lisp` — add parser exports (parse function, imports from tokenizer+types)

*Wave 0 creates test infrastructure; all subsequent tasks can verify immediately.*

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 2s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
