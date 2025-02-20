import pyfastx
from tempfile import NamedTemporaryFile

input = "/Users/bloyal/aho-drug-discovery-workflows/test_data/9ERW_COMPLEX.a3m"

with open(input, "r") as fin:
    lines = fin.read().splitlines(True)

seq_lengths = lines[0].strip().split("\t")[0][1:].split(",")

print(seq_lengths)

with NamedTemporaryFile(mode="w") as fp:
    fp.write("\n".join(str(item) for item in lines[1:]))
    fa = pyfastx.Fasta(fp.name)

print(fa[2])
print(len(fa))
print(fa.size)
print(fa.longest.name)
print(fa.keys())
