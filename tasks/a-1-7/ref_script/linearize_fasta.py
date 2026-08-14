
import os

task_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

input_fasta = os.path.join(task_dir, "data", "multi_line.fa")
output_fasta = os.path.join(task_dir, "ref_answer", "single_line.fa")

def convert_fasta_to_single_line(input_path, output_path):
    if not os.path.isfile(input_path):
        raise FileNotFoundError(f"Input file not found: {input_path}")
    with open(input_path, 'r') as infile, open(output_path, 'w') as outfile:
        seq = ''
        header = None
        for line in infile:
            line = line.rstrip('\n')
            if line.startswith('>'):
                if header is not None:
                    outfile.write(header + '\n')
                    outfile.write(seq + '\n')
                header = line
                seq = ''
            else:
                seq += line
        if header is not None:
            outfile.write(header + '\n')
            outfile.write(seq + '\n')

convert_fasta_to_single_line(input_fasta, output_fasta)
