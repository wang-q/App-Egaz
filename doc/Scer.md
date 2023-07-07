# *Saccharomyces cerevisiae* strains

- [*Saccharomyces cerevisiae* strains](#saccharomyces-cerevisiae-strains)
    * [Prepare sequences](#prepare-sequences)
    * [Detailed steps](#detailed-steps)
        + [lastz and lav2axt](#lastz-and-lav2axt)
        + [lastz and lpcnam](#lastz-and-lpcnam)
        + [lastz with partitioned sequences](#lastz-with-partitioned-sequences)
    * [Template steps](#template-steps)

## Prepare sequences

* Download

```shell
mkdir -p ~/data/egaz/download
cd ~/data/egaz/download

# S288c (soft-masked) from Ensembl
curl -O http://ftp.ensembl.org/pub/release-105/fasta/saccharomyces_cerevisiae/dna/Saccharomyces_cerevisiae.R64-1-1.dna_sm.toplevel.fa.gz
curl -O http://ftp.ensembl.org/pub/release-105/gff3/saccharomyces_cerevisiae/Saccharomyces_cerevisiae.R64-1-1.105.gff3.gz

# RM11_1a
curl -O https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/149/365/GCA_000149365.1_ASM14936v1/GCA_000149365.1_ASM14936v1_genomic.fna.gz

# YJM789
curl -O https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/181/435/GCA_000181435.1_ASM18143v1/GCA_000181435.1_ASM18143v1_genomic.fna.gz

# Saccharomyces paradoxus CBS432
curl -O https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/002/079/055/GCF_002079055.1_ASM207905v1/GCF_002079055.1_ASM207905v1_genomic.fna.gz

# Saccharomyces pastorianus CBS 1483
curl -O https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/011/022/315/GCA_011022315.1_ASM1102231v1/GCA_011022315.1_ASM1102231v1_genomic.fna.gz

# Saccharomyces eubayanus FM1318
curl -O https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/001/298/625/GCF_001298625.1_SEUB3.0/GCF_001298625.1_SEUB3.0_genomic.fna.gz

find . -name "*.gz" | xargs gzip -t

```

* prepare

```shell
cd ~/data/egaz

# for `fasops check`
faops filter -N -s download/Saccharomyces_cerevisiae.R64-1-1.dna_sm.toplevel.fa.gz S288c.fa
egaz prepseq S288c.fa -o S288c -v

gzip -dcf download/Saccharomyces_cerevisiae.R64-1-1.105.gff3.gz > S288c/chr.gff
spanr gff --tag CDS S288c/chr.gff -o S288c/cds.json
faops masked S288c/*.fa | spanr cover stdin -o S288c/repeat.json
spanr merge S288c/repeat.json S288c/cds.json -o S288c/anno.json

faops filter -N -s download/GCA_000149365*.fna.gz RM11_1a.fa
egaz prepseq \
    RM11_1a.fa -o RM11_1a \
    --repeatmasker '--species Fungi --parallel 6' -v

egaz prepseq \
    download/GCA_000181435*.fna.gz -o YJM789 \
    --about 2000000 --min 1000 --repeatmasker '--species Fungi --parallel 6' -v

egaz prepseq \
    download/GCF_002079055*.fna.gz -o Spar \
    --repeatmasker '--species Fungi --parallel 6' -v

egaz prepseq \
    download/GCA_011022315*.fna.gz -o Spas \
    --about 2000000 --min 1000 --repeatmasker '--species Fungi --parallel 6' -v

egaz prepseq \
    download/GCF_001298625*.fna.gz -o Seub \
    --about 2000000 --min 1000 --repeatmasker '--species Fungi --parallel 6' -v

```

## Detailed steps

### lastz and lav2axt

```shell script
cd ~/data/egaz

egaz lastz \
    --set set01 --parallel 6 --verbose \
    S288c RM11_1a \
    -o S288cvsRM11_1a_lav2axt

find S288cvsRM11_1a_lav2axt -type f -name "*.lav" |
    parallel --no-run-if-empty --linebuffer -k -j 6 '
        >&2 echo {}
        egaz lav2axt {} -o {}.axt
    '

fasops axt2fas \
    -l 1000 -t S288c -q RM11_1a -s RM11_1a/chr.sizes \
    S288cvsRM11_1a_lav2axt/*.axt -o S288cvsRM11_1a_lav2axt.fas

fasops check S288cvsRM11_1a_lav2axt.fas S288c.fa --name S288c -o stdout | grep -v "OK"
fasops check S288cvsRM11_1a_lav2axt.fas RM11_1a.fa --name RM11_1a -o stdout | grep -v "OK"

cat S288cvsRM11_1a_lav2axt.fas |
    grep "^>S288c." |
    spanr cover stdin |
    spanr stat S288c/chr.sizes stdin -o S288cvsRM11_1a_lav2axt.csv

```

### lastz and lpcnam

```shell script
cd ~/data/egaz

egaz lastz \
    --set set01 -C 0 --parallel 6 --verbose \
    S288c RM11_1a \
    -o S288cvsRM11_1a_lpcnam

# UCSC's pipeline
egaz lpcnam \
    --parallel 6 --verbose \
    S288c RM11_1a S288cvsRM11_1a_lpcnam

fasops axt2fas \
    -l 1000 -t S288c -q RM11_1a -s RM11_1a/chr.sizes \
    S288cvsRM11_1a_lpcnam/axtNet/*.net.axt.gz -o S288cvsRM11_1a_lpcnam_axt.fas

fasops check S288cvsRM11_1a_lpcnam_axt.fas S288c.fa --name S288c -o stdout | grep -v "OK"
fasops check S288cvsRM11_1a_lpcnam_axt.fas RM11_1a.fa --name RM11_1a -o stdout | grep -v "OK"

cat S288cvsRM11_1a_lpcnam_axt.fas |
    grep "^>S288c." |
    spanr cover stdin |
    spanr stat S288c/chr.sizes stdin -o S288cvsRM11_1a_lpcnam_axt.csv

# UCSC's syntenic pipeline
egaz lpcnam \
    --parallel 8 --verbose --syn \
    S288c RM11_1a S288cvsRM11_1a_lpcnam/lav.tar.gz -o S288cvsRM11_1a_lpcnam_syn

fasops maf2fas S288cvsRM11_1a_lpcnam_syn/mafSynNet/*.synNet.maf.gz -o S288cvsRM11_1a_lpcnam_syn.fas

fasops check S288cvsRM11_1a_lpcnam_syn.fas S288c.fa --name S288c -o stdout | grep -v "OK"
fasops check S288cvsRM11_1a_lpcnam_syn.fas RM11_1a.fa --name RM11_1a -o stdout | grep -v "OK"

cat S288cvsRM11_1a_lpcnam_syn.fas |
    grep "^>S288c." |
    spanr cover stdin |
    spanr stat S288c/chr.sizes stdin -o S288cvsRM11_1a_lpcnam_syn.csv

```

### lastz with partitioned sequences

```shell script
cd ~/data/egaz

find S288c -type f -name "*.fa" |
    parallel --no-run-if-empty --linebuffer -k -j 6 '
        >&2 echo {}
        egaz partition {} --chunk 500000 --overlap 10000
    '

egaz lastz \
    --set set01 -C 0 --parallel 6 --verbose \
    S288c RM11_1a --tp \
    -o S288cvsRM11_1a_partition

egaz lpcnam \
    --parallel 6 --verbose \
    S288c RM11_1a S288cvsRM11_1a_partition

fasops axt2fas \
    -l 1000 -t S288c -q RM11_1a -s RM11_1a/chr.sizes \
    S288cvsRM11_1a_partition/axtNet/*.net.axt.gz -o S288cvsRM11_1a_partition.fas

fasops check S288cvsRM11_1a_partition.fas S288c.fa --name S288c -o stdout | grep -v "OK"
fasops check S288cvsRM11_1a_partition.fas RM11_1a.fa --name RM11_1a -o stdout | grep -v "OK"

cat S288cvsRM11_1a_partition.fas |
    grep "^>S288c." |
    spanr cover stdin |
    spanr stat S288c/chr.sizes stdin -o S288cvsRM11_1a_partition.csv

```

### A quick dotplot

```shell
cd ~/data/egaz

brew install wang-q/tap/wfmash
cargo install --git https://github.com/ekg/pafplot --branch main

wfmash S288c/chr.fasta RM11_1a/chr.fasta > aln.paf
paf2dotplot png medium aln.paf

pafplot aln.paf

```

## Template steps

```shell script
cd ~/data/egaz

egaz template \
    S288c RM11_1a YJM789 Spar Spas Seub \
    --multi -o multi6/ \
    --mash --parallel 6 -v

bash multi6/1_pair.sh
bash multi6/2_mash.sh
bash multi6/3_multi.sh

egaz template \
    S288c RM11_1a YJM789 Spar \
    --multi -o multi6/ \
    --multiname multi4 --tree multi6/Results/multi6.raxml.nwk \
    --outgroup Spar \
    --vcf \
    --parallel 6 -v

bash multi6/3_multi.sh
bash multi6/4_vcf.sh
bash multi6/9_pack_up.sh

```

