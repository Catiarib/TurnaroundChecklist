# TurnaroundChecklist

> **In aviation, every minute on the ground matters**
> On-chain operational checklist + KPI measurement + NFT reputation badges
> Blockchain-based Aircraft Turnaround System | BCN | 2026

---

## Recognition

> **Winner — Blockchain-based Turnaround Checklist Challenge**
> Decode Travel Barcelona 2025
> Issued jointly by **Chain4Travel**, **Camino Network**, and **Vueling Airlines** (December 2025)

### Team

| Role | Contributor | Contribution |
|------|-------------|-------------|
| Smart Contracts | Alejandro Sáez | On-chain turnaround logic, KPI/SLA computation, cryptographic certification, NFT badge system |
| Frontend & dApp | Daniel Montaño | Frontend, wallet integrations, full decentralized application |
| Operations Design | Cátia Ribeiro | Real-world aircraft turnaround expertise, task model, actor responsibilities, SLA logic |

---

## What is TurnaroundChecklist?

The **TurnaroundChecklist** system introduces a **next-generation digital operating model for aircraft turnarounds**, transforming the entire arrival-to-departure process into a **cryptographically certified, on-chain operational checklist**.

Each turnaround is represented by a dedicated smart contract that:
- Enforces task accountability
- Measures real-time performance
- Computes SLA/KPI outcomes
- Produces an immutable operational certificate

A complementary **TurnaroundBadge** NFT contract enables a **reputation-based incentive layer** for operational actors delivering flawless performance.

```
Aircraft Arrival → 27 Tasks On-Chain → Real-Time KPIs → Certified Turnaround + NFT Badge
```

---

## Purpose & Strategic Intent

- Bring **operational transparency and accountability** to aircraft turnarounds
- Provide **objective, tamper-proof SLA and KPI measurement**
- Eliminate post-operation disputes through **cryptographic evidence**
- Introduce **performance-driven incentives** for ground operations
- Serve as a **foundational layer for automation, analytics, and compliance**

---

## High-Level Architecture

The solution consists of four core components:

### 1. TurnaroundChecklist (Core Contract)
Manages a single aircraft turnaround end-to-end:
- Task lifecycle management
- Role-based execution
- KPI/SLA computation
- Final certification
- Event-driven audit trail
- Optional badge issuance

### 2. TurnaroundTemplates (Library)
Initializes a **standardized 27-task turnaround checklist** with:
- Predefined operational actors
- Deadlines relative to scheduled arrival
- Default mandatory flags

### 3. TurnaroundTypes (Shared Types)
Defines common enums, structs, and events used across contracts.

### 4. TurnaroundBadge (ERC-721 NFT Contract)
Issues **performance badges** linked to a specific turnaround and actor:
- Fully on-chain metadata
- IPFS-hosted imagery
- Strong traceability to operational outcomes

---

## Operational Actor Model

The system models **six standard turnaround actors**, each operating through a dedicated blockchain wallet:

| Actor | Responsibility |
|-------|---------------|
| Ground Handling | Aircraft marshalling, push-back, GPU connection |
| Cleaning | Cabin cleaning and waste removal |
| Fuel | Fuelling and fuel upload confirmation |
| Catering | Catering loading and galley provisioning |
| Flight Crew | Pre-flight checks, departure readiness |
| Gate | Boarding, door management, PAX flow |

Each wallet enables:
- Clear responsibility attribution
- Verifiable action ownership
- Actor-level performance analytics

---

## Task Model & SLA Logic

Each turnaround contains **27 predefined operational tasks**, each defined by:

| Field | Description |
|-------|-------------|
| `actor` | Responsible operational actor |
| `deadline` | Time-bound deadline (relative to scheduled arrival) |
| `mandatory` | Whether task is mandatory or optional |
| `status` | `Pending` / `OnTime` / `Late` |
| `justification` | Optional delay justification (human-readable) |

> Late tasks that are **formally justified** do not count against SLA or KPI metrics, reflecting real-world operational exceptions.

---

## Access Control & Governance

The contract uses **OpenZeppelin AccessControl**, aligned with real aviation governance:

| Role | Permissions |
|------|-------------|
| `DEFAULT_ADMIN_ROLE` | Role administration, actor wallet management, badge contract configuration |
| `OPS_ROLE` | Turnaround certification, mandatory task overrides, operational override |
| Actor Wallets | Complete assigned tasks, justify delays for owned tasks |

---

## Turnaround Lifecycle

### Phase 1 — Deployment
Each smart contract represents **one specific turnaround**, initialized with:
- Off-chain turnaround ID
- Airport code
- Scheduled arrival and departure times
- Automatic 27-task generation

### Phase 2 — Operational Execution
- Actors mark tasks as completed via their wallets
- System evaluates timeliness in real time
- KPIs update continuously on-chain

### Phase 3 — Delay Justification
- Late tasks may be justified with human-readable reasons
- SLA impact is dynamically recalculated

### Phase 4 — Certification
Once all mandatory tasks are completed, OPS certifies the turnaround:
- On-time vs late task count
- SLA breach status
- Actual operational duration
- A **cryptographic certificate hash** is generated and stored immutably on-chain

---

## KPIs & Performance Metrics

The contract computes and exposes:

| Metric | Description |
|--------|-------------|
| Total tasks | Count of all turnaround tasks |
| Tasks on time | Tasks completed within deadline |
| Unjustified late tasks | Late tasks without formal justification |
| SLA breach indicator | Boolean: whether SLA was breached |
| Actual duration | Real operational time (arrival to departure) |

These KPIs are **trustless, auditable, and machine-readable**, enabling seamless integration with analytics platforms (Power BI, Tableau, etc.).

---

## Performance Badges (NFT Layer)

The **TurnaroundBadge** ERC-721 contract introduces a reputation mechanism:

- One badge per (turnaround, actor) pair
- Minted **only if** the actor:
  - Participated in the turnaround
  - Had **zero unjustified late tasks**
- Metadata is fully on-chain
- Visual assets stored on IPFS

> These badges are **non-financial reputation markers**, not speculative assets.

---

## Auditability & Traceability

A comprehensive event log ensures full transparency:

| Event | Trigger |
|-------|----------|
| `TurnaroundCreated` | Contract deployment |
| `TaskCompleted` | Actor marks task done |
| `MandatoryTaskChanged` | Admin modifies mandatory flag |
| `DelayJustified` | Actor submits delay reason |
| `TurnaroundCertified` | OPS certifies completion |
| `BadgeMinted` | NFT badge issued to actor |

Supports: post-operation audits, dispute resolution, regulatory compliance, historical performance analysis.

---

## Security & Operational Considerations

- Administrative and OPS roles must be tightly secured (hardware wallets recommended)
- Actor wallets represent **real operational authority**
- Badge minting restrictions fully enforced in production
- `block.timestamp` usage appropriate for minute-level operational windows
- **One-contract-per-turnaround model** minimizes systemic risk and simplifies audits

---

## Strategic Value for Airlines & Airports

This architecture transforms the aircraft turnaround from a **reactive, opaque process** into a **programmable, certifiable operational system**.

### Immediate Value
- Verifiable turnaround execution
- Objective SLA enforcement
- Performance-driven accountability

### Foundation For
- AI-driven disruption management
- Automated settlements and penalties
- B2B operational reputation systems
- Data-driven continuous improvement

> It introduces a **trust layer for aviation ground operations**, ready for scalable, digital-first ecosystems.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Smart Contracts | Solidity + OpenZeppelin |
| Blockchain | Camino Network (Chain4Travel) |
| NFT Standard | ERC-721 |
| Access Control | OpenZeppelin AccessControl |
| Asset Storage | IPFS |
| Frontend | dApp (wallet integration) |
| Analytics Integration | REST API / Power BI |

---

## Repository Structure

```
TurnaroundChecklist/
├── README.md                         # This document
├── contracts/
│   ├── TurnaroundChecklist.sol        # Core turnaround contract
│   ├── TurnaroundBadge.sol            # ERC-721 NFT badge contract
│   ├── TurnaroundTemplates.sol        # 27-task template library
│   └── TurnaroundTypes.sol            # Shared enums, structs, events
├── docs/
│   ├── architecture.md               # Technical architecture detail
│   ├── task-model.md                 # 27-task breakdown & SLA logic
│   └── actor-model.md                # Operational actor definitions
├── data-layer/
│   ├── kpi_schema.sql                # KPI data schema for analytics
│   └── kpi_dashboard.py              # Python ETL for Power BI
└── assets/
    └── badge-metadata/               # NFT badge metadata templates
```

---

## Related Articles

- [In aviation, every minute on the ground matters](https://medium.com/@catiaribeiro19/in-aviation-every-minute-on-the-ground-matters-a96af5eed6c7) — Medium, Cátia Ribeiro

---

## Author

**Cátia Ribeiro** — Operations Design & Strategy
Product & CX strategist exploring the future of aviation and travel tech.
Designing systems where technology meets human experience.
Barcelona, 2026

> *"In aviation, every minute on the ground matters. This system makes every second accountable."*
