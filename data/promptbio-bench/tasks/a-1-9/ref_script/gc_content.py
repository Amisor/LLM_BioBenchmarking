from Bio import SeqIO
import os
import csv

task_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

fasta_file = os.path.join(task_dir, "data", "seq.fasta")
output_file = os.path.join(task_dir, "ref_answer", "gc_content.tsv")

def calc_gc_content(seq):
    seq = seq.upper()
    g = seq.count("G")
    c = seq.count("C")
    valid_bases = sum(seq.count(base) for base in ["A", "T", "G", "C"])
    if valid_bases == 0:
        return 0
    return (g + c) / valid_bases * 100

with open(output_file, "w", newline="") as csvfile:
    writer = csv.writer(csvfile, delimiter="\t")
    writer.writerow(["Sequence_ID", "GC_percent"])
    for record in SeqIO.parse(fasta_file, "fasta"):
        gc_content = calc_gc_content(str(record.seq))
        writer.writerow([record.id, f"{gc_content:.2f}"])

