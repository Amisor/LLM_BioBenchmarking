#!/usr/bin/env python3
"""
ACMG-like variant classifier (3-tier: Pathogenic, VUS, Benign).

Input VCF must have INFO fields: CONSEQUENCE, GENE, AF, CLINVAR, SIFT, POLYPHEN.
Output TSV: CHROM, POS, ID, GENE, CONSEQUENCE, AF, CLINVAR, EVIDENCES, NOTES, CLASS
"""
import csv
import os

task_dir = os.path.dirname(os.path.dirname(__file__))
VCF_IN   = os.path.join(task_dir, "data",       "variants.vcf")
OUT_TSV  = os.path.join(task_dir, "ref_answer",  "acmg_classification.tsv")

LOF_CONSEQUENCES = {
    "stop_gained", "frameshift_variant",
    "splice_acceptor_variant", "splice_donor_variant",
}
OUT_FIELDS = ["CHROM", "POS", "ID", "GENE", "CONSEQUENCE", "AF",
              "CLINVAR", "EVIDENCES", "NOTES", "CLASS"]


def parse_info(info_str):
    return dict(token.split("=", 1) for token in info_str.split(";") if "=" in token)


def collect_evidence(cons, af, clin, sift, poly):
    evidences, notes = [], []

    # ClinVar
    if clin:
        if "pathogenic" in clin and "benign" not in clin:
            evidences.append("ClinVar_Pathogenic")
            notes.append("ClinVar reports pathogenic")
        elif "benign" in clin and "pathogenic" not in clin:
            evidences.append("ClinVar_Benign")
            notes.append("ClinVar reports benign")
        elif "conflicting" in clin:
            evidences.append("ClinVar_Conflicting")
            notes.append("ClinVar conflicting")

    # PVS1: predicted loss-of-function
    if any(t in cons for t in LOF_CONSEQUENCES):
        evidences.append("PVS1")
        notes.append("predicted loss-of-function (PVS1)")

    # BP7: synonymous variant
    if "synonymous_variant" in cons:
        evidences.append("BP7")
        notes.append("synonymous variant (BP7)")

    # PM2 / BA1: population frequency
    if af == 0 or af < 1e-4:
        evidences.append("PM2")
        notes.append(f"rare in population (AF={af})")
    elif af > 0.01:
        evidences.append("BA1")
        notes.append(f"common in population (AF={af})")

    # PP3 / BP4: computational predictors
    del_count = (sift in ("deleterious", "damaging")) + (poly in ("probably_damaging", "possibly_damaging"))
    ben_count = (sift in ("tolerated", "benign"))     + (poly == "benign")
    if del_count >= 1 and ben_count == 0:
        evidences.append("PP3")
        notes.append("computational evidence supports deleterious (PP3)")
    elif ben_count >= 1 and del_count == 0:
        evidences.append("BP4")
        notes.append("computational evidence supports benign (BP4)")

    return evidences, notes


def classify(evidences):
    ev = set(evidences)
    if "ClinVar_Pathogenic" in ev:
        return "Pathogenic"
    if "BA1" in ev or "ClinVar_Benign" in ev:
        return "Benign"
    if "PVS1" in ev or ("PM2" in ev and "PP3" in ev):
        return "Pathogenic"
    if "BP7" in ev and ("BP4" in ev or "BA1" in ev):
        return "Benign"
    return "VUS"


def classify_variant(rec):
    info = rec["info"]
    cons = info.get("CONSEQUENCE", ".")
    af   = float(info.get("AF", "0") or 0)
    clin = info.get("CLINVAR", "").lower()
    sift = info.get("SIFT",    "").lower()
    poly = info.get("POLYPHEN","").lower()

    evidences, notes = collect_evidence(cons, af, clin, sift, poly)
    return {
        "CHROM":       rec["CHROM"],
        "POS":         rec["POS"],
        "ID":          rec["ID"],
        "GENE":        info.get("GENE", "."),
        "CONSEQUENCE": cons,
        "AF":          af,
        "CLINVAR":     info.get("CLINVAR", ""),
        "EVIDENCES":   ";".join(evidences),
        "NOTES":       ";".join(notes),
        "CLASS":       classify(evidences),
    }


def read_vcf(path):
    variants = []
    with open(path) as fh:
        for line in fh:
            if line.startswith("#"):
                continue
            chrom, pos, vid, ref, alt, qual, flt, info = line.strip().split("\t")[:8]
            variants.append({
                "CHROM": chrom, "POS": pos, "ID": vid,
                "info": parse_info(info),
            })
    return variants


def main():
    rows = [classify_variant(v) for v in read_vcf(VCF_IN)]
    with open(OUT_TSV, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=OUT_FIELDS, delimiter="\t")
        w.writeheader()
        w.writerows(rows)
    print("Wrote:", OUT_TSV)


if __name__ == "__main__":
    main()
