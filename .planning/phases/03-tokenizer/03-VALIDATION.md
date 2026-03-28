---
phase: 03
slug: tokenizer
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-28
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Hand-rolled (deftest/assert-equal/assert-true/assert-signals) |
| **Config file** | tests/test-framework.lisp |
| **Quick run command** | `./run-tests.sh` |
| **Full suite command** | `./run-tests.sh` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `./run-tests.sh`
- **After every plan wave:** Run `./run-tests.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 2 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | TOK-01..18 | unit | `./run-tests.sh` | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 2 | TOK-01..08 | unit | `./run-tests.sh` | ❌ W0 | ⬜ pending |
| 03-03-01 | 03 | 2 | TOK-09..18 | unit | `./run-tests.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test-tokenizer.lisp` — test file for tokenizer tests
- [ ] `tests/packages.lisp` — add `innate.tests.tokenizer` package

*Existing test infrastructure (deftest, assert-equal, assert-true, assert-signals) covers all framework needs.*

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
