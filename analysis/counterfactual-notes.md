# Counterfactual Interpretation Notes

## The Three (Now Four) Counterfactuals

All counterfactuals replace PCP beliefs $m_{ij}$ with true specialist quality $q_j$. They differ in how familiarity is handled.

| Counterfactual | Beliefs | Familiarity | Convergence |
|---|---|---|---|
| **Current** | $q_j$ | Starts at existing baseline | `converge_dyn` |
| **Full** | $q_j$ | Rebuilt from 0 | `converge_dyn` |
| **FullFam** | $q_j$ | Set to 0 permanently | `converge` |
| **FullNoFE** | $q_j$ | Rebuilt from 0, $\xi_j = 0$ | `converge_dyn` |

## Results (Myopic, March 2026 run)

**Reallocation** (share of patients changing specialists):
- Current: ~22% (centered)
- Full: ~30%
- FullFam: ~37%

**Health effects** (change in expected probability of success):
- Current: centered near 0, slightly positive
- Full: centered near 0, slightly negative
- FullFam: clearly negative (~-0.003 mean)

## Why does more information not always help?

### The key mechanism: specialist FEs dominate

The utility for specialist $j$ is:

$$U_{ij} = \beta_d \cdot d_{ij} + \alpha \cdot m_{ij} + f_{ij} + \xi_j + \gamma \cdot N_j$$

The specialist FE ($\xi_j$) captures all non-quality appeal (scheduling, reputation, hospital affiliation, etc.). In the data, familiarity coefficients range from ~1.2 (1 prior referral) to ~3.2 (20+ referrals), while $\alpha \cdot q$ spans only ~0.035 across the full quality range (with $\alpha \approx 0.23$ and quality ranging ~0.80 to 0.95). Familiarity from a single referral is roughly 35x larger than the entire quality spread through the alpha channel.

### Toy example

One PCP, three specialists:

| Specialist | True quality ($q_j$) | FE ($\xi_j$) | Historical patients | Existing familiarity ($f$) |
|---|---|---|---|---|
| A | 0.95 | 0.5 | 8 | 1.0 |
| B | 0.85 | 2.0 | 3 | 0.5 |
| C | 0.80 | 1.0 | 1 | 0.0 |

With $\alpha = 0.2$:

**Current** (replace beliefs, keep familiarity):
- $U_A = 0.19 + 1.0 + 0.5 = 1.69 \rightarrow p_A = 0.235$
- $U_B = 0.17 + 0.5 + 2.0 = 2.67 \rightarrow p_B = 0.627$
- $U_C = 0.16 + 0.0 + 1.0 = 1.16 \rightarrow p_C = 0.138$
- Health = 0.235(0.95) + 0.627(0.85) + 0.138(0.80) = **0.866**

**Full** (replace beliefs, reset familiarity to 0):
- $U_A = 0.19 + 0.0 + 0.5 = 0.69 \rightarrow p_A = 0.143$
- $U_B = 0.17 + 0.0 + 2.0 = 2.17 \rightarrow p_B = 0.628$
- $U_C = 0.16 + 0.0 + 1.0 = 1.16 \rightarrow p_C = 0.229$
- Health = 0.143(0.95) + 0.628(0.85) + 0.229(0.80) = **0.853**

Full is worse by 0.013. The high-quality specialist (A) loses patients because without familiarity, A's low FE leaves it uncompetitive. Familiarity rebuilds with the FE-favored specialists (B), not the quality-favored specialist (A), because the quality signal ($\alpha \cdot q$) is too weak to redirect the initial allocation.

### Why Current beats Full

Existing familiarity is not just inertia. It is a record of past learning. The PCP built up 8 referrals to A because A performed well over time. That accumulated familiarity counterbalances A's low FE. Resetting familiarity forces the system to restart from an FE-driven allocation, and with small $\alpha$, the quality signal cannot overcome the FE gradient fast enough to rebuild familiarity with the right specialists.

### Why FullFam is worst

With familiarity permanently off, the utility is just $\alpha \cdot q + \xi_j + \gamma \cdot N_j + \beta_d \cdot d$. Since $\alpha \cdot q$ is small relative to $\xi_j$, the allocation is almost entirely FE-driven. Congestion redistributes patients from the most popular specialist, but toward specialists with the next-highest FEs, not the highest quality.

### The role of alpha

For full information to improve health, $\alpha$ must be large enough relative to the spread of $\xi_j$ that the quality signal can overcome FE differences. Specifically, for the quality signal to redirect a patient from specialist B to specialist A, we need:

$$\alpha \cdot (q_A - q_B) > \xi_B - \xi_A$$

In the toy example, $\alpha \cdot 0.10 = 0.02$ vs $\xi_B - \xi_A = 1.5$. The gradient plots show this pattern in the data: higher-$\alpha$ markets tend toward positive health effects.

## The "value of decentralized learning" interpretation

The Current counterfactual (roughly neutral health effects) suggests that PCPs are already learning reasonably well through experience. Their beliefs $m_{ij}$ are approximately correct for the specialists they actively use. The informational friction is not the binding constraint.

The binding constraint is that non-quality factors ($\xi_j$) dominate referral decisions. Full information alone cannot fix this because the quality signal is too weak relative to FE variation. Familiarity, built through accumulated experience, is what allows quality to compete with FEs.

## New counterfactual: FullNoFE

To isolate the value of quality information in a world where it can actually drive decisions, we add a counterfactual with $\xi_j = 0$. This asks: if specialists only differed on quality, distance, familiarity, and congestion, how much would full information help?

This is interpretable as a decision-support intervention that strips away non-quality factors from the referral decision.

## New counterfactual: QualMax

EHR-style intervention: PCPs see a quality-ranked list of specialists and must act on it, deviating only for legitimate practical reasons (distance, congestion). Removes FEs and familiarity entirely; inflates $\alpha$ so quality is the primary driver.

$$U_{ij} = \beta_d \cdot d_{ij} + \alpha_{new} \cdot q_j + \gamma \cdot N_j$$

Three $\alpha$ scenarios per HRR:

| Scenario | $\alpha$ value | Interpretation |
|---|---|---|
| **a1** | 1 | Quality as numeraire |
| **amatch** | $\max\!\bigl(\frac{|\beta_d| \cdot \text{SD}(d)}{~\text{SD}(q)~},\; \frac{|\gamma| \cdot \text{SD}(N)}{~\text{SD}(q)~}\bigr)$ | Quality matches strongest practical constraint |
| **ahigh** | $2 \times$ amatch | Quality clearly dominates |

All SDs computed within-HRR. Uses `converge` (static equilibrium, no familiarity dynamics).

The key design choice: $\alpha_{amatch}$ is calibrated per-HRR so that a 1 SD quality improvement generates the same utility as a 1 SD change in whichever practical constraint (distance or congestion) is stronger in that market. This is the "PCP who takes quality as seriously as geography" benchmark.
