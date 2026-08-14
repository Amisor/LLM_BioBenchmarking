
#!/usr/bin/env python3

import os
import sys

task_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

output_path = os.path.join(task_dir, "ref_answer", "sequence.fasta")

seq = "AATTGGGACCAACACTAGAATATCACCCTCCCTCTGGTCCTGAGGGAGAGGAATCCTCCTGGGTTTCCAGATCCTG"

# Generate reverse complement
complement = str.maketrans('ACGTacgtNn', 'TGCAtgcaNn')
revcomp = seq.translate(complement)[::-1]

# Write to FASTA
with open(output_path, 'w') as f:
    f.write(">reverse_complement\n")
    # Wrap sequence at 60 chars per line (FASTA convention)
    for i in range(0, len(revcomp), 60):
        f.write(revcomp[i:i+60] + '\n')
