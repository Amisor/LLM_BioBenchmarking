import os
from Bio import SeqIO
import pandas as pd
import logging

task_dir = os.path.dirname(os.path.dirname(__file__))

# Set up logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)

# Input FASTA file
input_fasta = os.path.join(task_dir, "data", "dna_parts.fasta")

# Define BsaI recognition site and overhangs
BSAI_SITE = "GGTCTC"
OVERHANGS = {
    "part1_promoter": ("ATCG", "CTAG"),
    "part2_gene": ("CTAG", "TACG"),
    "part3_terminator": ("TACG", "TGCA"),
    "part4_backbone": ("TGCA", "ATCG"),
}
ASSEMBLY_ORDER = ["part1_promoter", "part2_gene", "part3_terminator", "part4_backbone"]

# Parse DNA parts
try:
    parts = {
        record.id: str(record.seq).upper()
        for record in SeqIO.parse(input_fasta, "fasta")
    }
    logging.info(f"Parsed {len(parts)} DNA parts")
except Exception as e:
    logging.error(f"Error parsing FASTA: {str(e)}")
    exit(1)


# Simulate BsaI digestion
def digest_part(part_seq, part_id):
    if BSAI_SITE not in part_seq:
        logging.error(f"No BsaI site found in {part_id}")
        return None, None
    start_overhang, end_overhang = OVERHANGS[part_id]
    # Extract sequence between BsaI site and overhang
    start_idx = part_seq.index(BSAI_SITE) + len(BSAI_SITE) + 1
    # Assume second BsaI site or end of sequence
    second_bsaI = part_seq.find(BSAI_SITE, start_idx)
    if second_bsaI == -1:
        second_bsaI = len(part_seq)
    fragment = part_seq[start_idx:second_bsaI]
    return fragment, (start_overhang, end_overhang)


# Digest all parts
fragments = {}
for part_id, seq in parts.items():
    fragment, overhangs = digest_part(seq, part_id)
    if fragment:
        fragments[part_id] = {"sequence": fragment, "overhangs": overhangs}
        logging.info(
            f"Digested {part_id}: {overhangs[0]} -> {fragment[:10]}... -> {overhangs[1]}"
        )
    else:
        logging.error(f"Failed to digest {part_id}")
        exit(1)

# Assemble plasmid
assembled_sequence = ""
map_lines = []
current_pos = 1

for part_id in ASSEMBLY_ORDER:
    if part_id not in fragments:
        logging.error(f"Part {part_id} not found in fragments")
        exit(1)
    fragment = fragments[part_id]["sequence"]
    assembled_sequence += fragment
    map_lines.append(
        f"{part_id}: {current_pos}-{current_pos+len(fragment)-1} ({len(fragment)} bp)"
    )
    current_pos += len(fragment)

# Verify circularity (backbone overhangs match)
if (
    fragments[ASSEMBLY_ORDER[0]]["overhangs"][0]
    != fragments[ASSEMBLY_ORDER[-1]]["overhangs"][1]
):
    logging.warning(
        "Overhangs do not match for circularization. Linear construct assumed."
    )

# Save assembled sequence
output = [{"Sequence": assembled_sequence, "Length": len(assembled_sequence)}]
df = pd.DataFrame(output)
df.to_csv(os.path.join(task_dir, "ref_answer", "assembled_plasmid.csv"), index=False)

# Generate plasmid map
map_content = "Plasmid Map\n" + "=" * 20 + "\n"
map_content += f"Total Length: {len(assembled_sequence)} bp\n\n"
map_content += "Features:\n" + "\n".join(map_lines)
with open(os.path.join(task_dir, "ref_answer", "plasmid_map.txt"), "w") as f:
    f.write(map_content)

# Print summary
print("Assembled Plasmid Summary:")
print(f"Total Length: {len(assembled_sequence)} bp")
print("\nPlasmid Map:")
print("\n".join(map_lines))
