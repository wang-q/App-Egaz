# Self-alignment of *Saccharomyces cerevisiae* S288c

[TOC levels=1-3]: # " "
- [Self-alignment of *Saccharomyces cerevisiae* S288c](#self-alignment-of-saccharomyces-cerevisiae-s288c)
- [Prepare sequences](#prepare-sequences)
- [Detailed steps](#detailed-steps)
    - [self alignement](#self-alignement)
    - [blast](#blast)


# Prepare sequences

In [here](Scer.md#prepare-sequences).

Each .fa files in <path/target> should contain only one sequences.

# Detailed steps

## self alignement

```bash
cd ~/data/alignment/egaz

egaz lastz \
    --set set01 -C 0 --parallel 8 --isself --verbose \
    S288c S288c \
    -o S288cvsSelf

egaz lpcnam \
    --parallel 8 --verbose \
    S288c S288c S288cvsSelf

fasops axt2fas \
    -l 1000 -t S288c -q S288c -s S288c/chr.sizes \
    S288cvsSelf/axtNet/*.net.axt.gz -o S288cvsSelf_axt.fas

fasops check S288cvsSelf_axt.fas S288c.fa --name S288c -o stdout | grep -v "OK"

fasops covers S288cvsSelf_axt.fas -n S288c -o stdout |
    runlist stat -s S288c/chr.sizes stdin -o S288cvsSelf_axt.csv

```

## blast


```bash
cd ~/data/alignment/egaz

mkdir -p S288c_proc
mkdir -p S288c_result

cd ~/data/alignment/egaz/S288c_proc

# genome
find ../S288c -type f -name "*.fa" |
    sort |
    xargs cat |
    perl -nl -e '/^>/ or $_ = uc; print' \
    > genome.fa
faops size genome.fa > chr.sizes

# Get exact copies in the genome
fasops axt2fas ../S288cvsSelf/axtNet/*.axt.gz -l 1000 -s chr.sizes -o stdout > axt.fas
fasops separate axt.fas --nodash -s .sep.fasta

echo "* Target positions"
egaz exactmatch target.sep.fasta genome.fa \
    --length 500 -o replace.target.tsv
fasops replace axt.fas replace.target.tsv -o axt.target.fas

echo "* Query positions"
egaz exactmatch query.sep.fasta genome.fa \
    --length 500 -o replace.query.tsv
fasops replace axt.target.fas replace.query.tsv -o axt.correct.fas

# coverage stats
fasops covers axt.correct.fas -o axt.correct.yml
runlist split axt.correct.yml -s .temp.yml
runlist compare --op union target.temp.yml query.temp.yml -o axt.union.yml
runlist stat --size chr.sizes axt.union.yml -o union.csv

# links by lastz-chain
fasops links axt.correct.fas -o stdout |
    perl -nl -e 's/(target|query)\.//g; print;' \
    > links.lastz.tsv

# remove species names
# remove duplicated sequences
# remove sequences with more than 250 Ns
fasops separate axt.correct.fas --nodash --rc -o stdout |
    perl -nl -e '/^>/ and s/^>(target|query)\./\>/; print;' |
    faops filter -u stdin stdout |
    faops filter -n 250 stdin stdout \
    > axt.gl.fasta

# Get more paralogs
egaz blastn axt.gl.fasta genome.fa -o axt.bg.blast
perl ~/Scripts/egaz/blastn_genome.pl -f axt.bg.blast -g genome.fa -o axt.bg.fasta -c 0.95

cat axt.gl.fasta axt.bg.fasta |
    faops filter -u stdin stdout |
    faops filter -n 250 stdin stdout \
    > axt.all.fasta

# link paralogs
echo "* Link paralogs"
perl ~/Scripts/egaz/fasta_blastn.pl   -f axt.all.fasta -g axt.all.fasta -o axt.all.blast
perl ~/Scripts/egaz/blastn_paralog.pl -f axt.all.blast -c 0.95 -o links.blast.tsv

```

