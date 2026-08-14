# Unified Benchmark Evaluation Architecture

## Current Implementation

``` text
eval.json
    ↓
reference output
    ↓
candidate output
    ↓
numeric comparator
    ↓
mechanical rubric checks
    ↓
NEEDS_JUDGE for everything else
```

------------------------------------------------------------------------

## Proposed Generalized Architecture

``` mermaid
flowchart TD
    A["Benchmark Task Spec"]

    A --> B["Agent Execution"]
    A --> C["Evaluation"]

    B --> D["Plan"]
    B --> E["Code"]
    B --> F["Trace"]

    D --> G["Candidate Outputs"]
    E --> G
    F --> G

    C --> H["Evaluator Registry"]

    G --> H

    H --> I["Mechanical Evaluators"]
    H --> J["Domain / Result Evaluators"]
    H --> K["Semantic / Judge Evaluators"]

    I --> I1["File Present"]
    I --> I2["Parseable"]
    I --> I3["Paths"]
    I --> I4["Leakage"]
    I --> I5["Script"]

    J --> J1["Matrix / List / Labels"]
    J --> J2["Embedding"]
    J --> J3["Clustering"]
    J --> J4["Variants"]
    J --> J5["DE Results"]

    K --> K1["Plan Quality"]
    K --> K2["Biological Logic"]
    K --> K3["Code Quality"]
    K --> K4["Tool Choice"]
    K --> K5["Interpretation"]

    I --> L["Unified Rubric"]
    J --> L
    K --> L

    L --> M["Task + Dimension Scores"]
    M --> N["Robustness / Failure Diagnostics"]
```

------------------------------------------------------------------------

## Evaluation Pipeline

``` text
Benchmark Task Spec
        │
        ├── Agent Execution
        │     ├── Plan
        │     ├── Code
        │     └── Trace
        │
        └── Evaluation
               │
               ├── Candidate Outputs
               └── Evaluator Registry
                      ├── Mechanical Evaluators
                      │      • File present
                      │      • Parseable
                      │      • Paths
                      │      • Leakage
                      │      • Script
                      │
                      ├── Domain / Result Evaluators
                      │      • Matrix/List/Labels
                      │      • Embedding
                      │      • Clustering
                      │      • Variants
                      │      • DE Results
                      │
                      └── Semantic / Judge Evaluators
                             • Plan quality
                             • Biological logic
                             • Code quality
                             • Tool choice
                             • Interpretation

All evaluator outputs are aggregated into a **Unified Rubric**, producing:

- Task score
- Dimension scores
- Robustness diagnostics
- Failure diagnostics
```
