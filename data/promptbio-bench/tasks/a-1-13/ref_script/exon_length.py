import pandas as pd
import os

task_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def parse_gff(gff_file, gene_name, output_file):
    transcript_exons = {}

    with open(gff_file, "r") as f:
        for line in f:
            if line.startswith("#"):
                continue
            parts = line.strip().split("\t")
            if len(parts) < 9:
                continue

            feature_type = parts[2]
            if feature_type != "exon":
                continue

            chrom, source, feature, start, end, score, strand, phase, attributes = parts
            start, end = int(start), int(end)

            attr_dict = {}
            for attr in attributes.split(";"):
                if "=" in attr:
                    k, v = attr.split("=", 1)
                    attr_dict[k.strip()] = v.strip()
            if gene_name in attributes:
                print(attr_dict)
            if "gene" in attr_dict and attr_dict["gene"] == gene_name:
                transcript_id = attr_dict.get("transcript_id") or attr_dict.get("ID")
                if transcript_id is None:
                    continue

                if transcript_id not in transcript_exons:
                    transcript_exons[transcript_id] = []
                transcript_exons[transcript_id].append((start, end))

    results = []
    for transcript_id, intervals in transcript_exons.items():
        merged = []
        for start, end in sorted(intervals):
            if not merged or start > merged[-1][1]:
                merged.append([start, end])
            else:
                merged[-1][1] = max(merged[-1][1], end)

        total_len = sum(e - s + 1 for s, e in merged)
        results.append((transcript_id, total_len))

    df = pd.DataFrame(results, columns=["Transcript_ID", "Total_Exon_Length"])
    df.to_csv(output_file, sep="\t", index=False)

if __name__ == "__main__":
    
    gtf_file = os.path.join(task_dir, "data", "genomic.gff")
    out_file = os.path.join(task_dir, "ref_answer", "TP53_transcript_exon_lengths.tsv")
    parse_gff(gtf_file, gene_name="TP53", output_file=out_file)
