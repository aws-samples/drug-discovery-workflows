import sys
from Bio import SeqIO


infile = sys.argv[1]
outfile = sys.argv[2]

with open(outfile, "w") as out_fh:
    with open(infile, "r") as in_fh:
        for record in SeqIO.parse(in_fh, "fasta"):
            if not "0" in record.seq:
                SeqIO.write(record, out_fh, "fasta")
