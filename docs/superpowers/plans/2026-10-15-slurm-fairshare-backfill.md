# Slurm Fairshare and Backfill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the agreed fairshare and backfill policy in local configuration only.

**Architecture:** Keep one partition per compute node, the existing Slurm/OOD interfaces, and non-preemptive execution. Declare policy in group variables and render it into the existing Slurm template. Preserve CPU billing at 0.1 and existing GPU/shard billing, Account shares, and QoS records.

**Tech Stack:** Ansible YAML, Jinja2, Slurm 25.11, Python unittest.

---

The user authorized direct local implementation. No SSH, playbook deployment,
service operation, commit, or push is part of this plan. Execute inline.

### Task 1: Declare and render the policy

**Files:**
- Modify: `ansible/inventory/group_vars/all/slurm.yml`
- Modify: `ansible/roles/slurm/templates/slurm.conf.j2`

- [x] Set the following group variables:

```yaml
slurm_scheduler_parameters: "bf_min_age_reserve=43200,bf_min_prio_reserve=70000,bf_job_part_count_reserve=1"
slurm_priority_flags: NO_FAIR_TREE
slurm_priority_decay_half_life: "7-0"
slurm_priority_calculation_period: 5
slurm_priority_max_age: "7-0"
slurm_priority_weight_fairshare: 100000
slurm_priority_weight_age: 70000
slurm_priority_weight_tres: "CPU=10000,GRES/gpu=10000,GRES/shard=10000"
slurm_priority_weight_qos: 100000
```

- [x] Add the missing template directives alongside their existing sections:

```jinja2
SchedulerParameters={{ slurm_scheduler_parameters }}
PriorityFlags={{ slurm_priority_flags }}
PriorityWeightTRES={{ slurm_priority_weight_tres }}
```

- [x] Replace Fair Tree comments with Classic fairshare descriptions. Leave
  node partitions, billing, association generation, QoS records, and preemption
  unchanged.

### Task 2: Explain the policy and verify locally

**Files:**
- Modify: `docs/user/03-queue.md`
- Modify: `docs/developer/06-superadmin.md`
- Run existing tests: `tests/test_slurm_associations_role.py`

- [x] Document the six priority contributions, 12-hour eligible-wait minimum,
  70000-point threshold, and one future reservation per partition. Distinguish
  seven-day age saturation from a start deadline, mutable backfill plans from
  running jobs, and repository configuration from deployed state.
- [x] Replace the deployment checklist's Fair Tree-specific wording.
- [x] Parse the changed YAML and render `slurm.conf.j2` with Jinja2 StrictUndefined
  using local group variables and all three compute host declarations. Check
  policy directives, one matching node per partition, CPU billing 0.1, existing
  GPU/shard billing, and disabled preemption.
- [x] Run `python -m unittest discover -s tests -p test_slurm_associations_role.py`.
  Expected: existing association and role contracts pass.
- [x] Run `git diff --check` and inspect the complete diff. Expected: no
  whitespace errors and no edits to unrelated configuration.

Native Slurm configuration parsing and live scheduling behavior cannot be
confirmed by a local Jinja2 render; they remain deployment-time validation.

Local verification passed: all 10 existing Slurm association tests, YAML loading,
and a StrictUndefined render covering 15 policy directives and all three node
partitions. CPU billing remains 0.1; GPU/shard billing, QoS records, partition
mapping, and disabled preemption were checked. No server connections or
deployment commands were used during implementation.
