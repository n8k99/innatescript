---
phase: 07
slug: evaluator-core
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-29
---

# Phase 07 — Validation Strategy

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
| 07-01-01 | 01 | 1 | EVL-01,EVL-08,EVL-14 | unit | `bash run-tests.sh` | ❌ W0 | ⬜ pending |
| 07-01-02 | 01 | 1 | EVL-11,EVL-12 | unit | `bash run-tests.sh` | ❌ W0 | ⬜ pending |
| 07-02-01 | 02 | 2 | EVL-02,EVL-03 | unit | `bash run-tests.sh` | ❌ W0 | ⬜ pending |
| 07-02-02 | 02 | 2 | EVL-15 | unit | `bash run-tests.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test-evaluator.lisp` — test file with `innate.tests.evaluator` package
- [ ] `tests/packages.lisp` — add `innate.tests.evaluator` package definition
- [ ] `innatescript.asd` — add `test-evaluator` component to test system
- [ ] `src/packages.lisp` — add evaluator exports and imports

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
