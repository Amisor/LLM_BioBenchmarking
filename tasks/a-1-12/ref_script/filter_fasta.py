#!/usr/bin/env python3
from Bio import SeqIO
import os

task_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def filter_fasta(input_fasta, output_fasta, keyword):
    with open(output_fasta, "w") as out_handle:
        for record in SeqIO.parse(input_fasta, "fasta"):
            if keyword in record.description:
                SeqIO.write(record, out_handle, "fasta")

input_fasta = os.path.join(task_dir, "data", "multifa.fa")
output_fasta = os.path.join(task_dir, "ref_answer", "sequence.fasta")
keyword = "Paenibacillus"

filter_fasta(input_fasta, output_fasta, keyword)
