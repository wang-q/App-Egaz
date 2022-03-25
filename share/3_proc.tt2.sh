[% INCLUDE header.tt2 %]

#----------------------------#
# [% sh %]
#----------------------------#
log_warn [% sh %]

mkdir -p Processing
mkdir -p Results

#----------------------------#
# genome sequences
#----------------------------#
[% FOREACH item IN opt.data -%]
if [ -d Processing/[% item.name %] ]; then
    log_info Skip Processing/[% item.name %]
else
    log_info Symlink genome sequences for [% item.name %]
    mkdir -p Processing/[% item.name %]

    ln -s [% item.dir %]/chr.fasta Processing/[% item.name %]/genome.fa
    cp -f [% item.dir %]/chr.sizes Processing/[% item.name %]/chr.sizes
fi

[% END -%]

#----------------------------#
# parallel
#----------------------------#
log_info Blast paralogs against genomes and each other

parallel --no-run-if-empty --linebuffer -k -j 2 '

if [ -d Results/{} ]; then
    echo >&2 "==> Skip Results/{}";
    exit;
fi

cd Processing/{}

#----------------------------#
# Get exact copies in the genome
#----------------------------#
echo >&2 "==> Get exact copies in the genome"

echo >&2 "    * axt2fas"
fasops axt2fas \
    ../../Pairwise/{}vsSelf/axtNet/*.axt.gz \
    -l [% opt.length %] -s chr.sizes -o stdout > axt.fas
fasops separate axt.fas -o . --nodash -s .sep.fasta

echo >&2 "    * Target positions"
egaz exactmatch target.sep.fasta genome.fa \
    --length 500 --discard 50 -o replace.target.tsv
fasops replace axt.fas replace.target.tsv -o axt.target.fas

echo >&2 "    * Query positions"
egaz exactmatch query.sep.fasta genome.fa \
    --length 500 --discard 50 -o replace.query.tsv
fasops replace axt.target.fas replace.query.tsv -o axt.correct.fas

#----------------------------#
# Coverage stats
#----------------------------#
echo >&2 "==> Coverage stats"
fasops covers axt.correct.fas -o axt.correct.yml
spanr split axt.correct.yml -s .temp.yml -o .
spanr compare --op union target.temp.yml query.temp.yml -o axt.union.yml
spanr stat chr.sizes axt.union.yml -o union.csv

# links by lastz-chain
fasops links axt.correct.fas -o stdout |
    perl -nl -e "s/(target|query)\.//g; print;" \
    > links.lastz.tsv

# remove species names
# remove duplicated sequences
# remove sequences with more than 250 Ns
fasops separate axt.correct.fas --nodash --rc -o stdout |
    perl -nl -e "/^>/ and s/^>(target|query)\./\>/; print;" |
    faops filter -u stdin stdout |
    faops filter -n 250 stdin stdout \
    > axt.gl.fasta

[% IF opt.noblast -%]
#----------------------------#
# Lastz paralogs
#----------------------------#
cat axt.gl.fasta > axt.all.fasta
[% ELSE -%]
#----------------------------#
# Get more paralogs
#----------------------------#
echo >&2 "==> Get more paralogs"
egaz blastn axt.gl.fasta genome.fa -o axt.bg.blast --parallel [% opt.parallel2 %]
egaz blastmatch axt.bg.blast -c 0.95 -o axt.bg.region --parallel [% opt.parallel2 %]
samtools faidx genome.fa -r axt.bg.region --continue |
    perl -p -e "/^>/ and s/:/(+):/" \
    > axt.bg.fasta

cat axt.gl.fasta axt.bg.fasta |
    faops filter -u stdin stdout |
    faops filter -n 250 stdin stdout \
    > axt.all.fasta
[% END -%]

#----------------------------#
# Link paralogs
#----------------------------#
echo >&2 "==> Link paralogs"
egaz blastn axt.all.fasta axt.all.fasta -o axt.all.blast --parallel [% opt.parallel2 %]
egaz blastlink axt.all.blast -c 0.95 -o links.blast.tsv --parallel [% opt.parallel2 %]

#----------------------------#
# Merge paralogs
#----------------------------#
echo >&2 "==> Merge paralogs"

echo >&2 "    * Sort links"
linkr sort -o links.sort.tsv \
[% IF opt.noblast -%]
   links.lastz.tsv
[% ELSE -%]
    links.lastz.tsv links.blast.tsv
[% END -%]

echo >&2 "    * Clean links"
linkr clean   links.sort.tsv       -o links.sort.clean.tsv
linkr merge   links.sort.clean.tsv -o links.merge.tsv       -c 0.95
linkr clean   links.sort.clean.tsv -o links.clean.tsv       -r links.merge.tsv --bundle 500

echo >&2 "    * Connect links"
linkr connect links.clean.tsv    -o links.connect.tsv     -r 0.9
linkr filter  links.connect.tsv  -o links.filter.tsv      -r 0.8

    ' ::: [% FOREACH item IN opt.data %][% item.name %] [% END %]

[% FOREACH item IN opt.data -%]
[% id = item.name -%]
#----------------------------#
# [% id %]
#----------------------------#
if [ -d Results/[% id %] ]; then
    log_info Skip Results/[% id %]
else

mkdir -p Results/[% id %]
pushd Processing/[% id %] > /dev/null

log_info Create multiple/pairwise alignments for [% id %]

log_debug multiple links
fasops create links.filter.tsv -o multi.temp.fas    -g genome.fa
fasops refine multi.temp.fas   -o multi.refine.fas  --msa mafft -p [% opt.parallel %] --chop 10
fasops links  multi.refine.fas -o stdout |
    linkr sort stdin -o stdout |
    linkr filter stdin -n 2-50 -o links.refine.tsv

log_debug pairwise links
fasops   links  multi.refine.fas    -o stdout     --best |
    linkr sort stdin -o links.best.tsv
fasops create links.best.tsv   -o pair.temp.fas    -g genome.fa --name [% id %]
fasops refine pair.temp.fas    -o pair.refine.fas  --msa mafft -p [% opt.parallel %]

cat links.refine.tsv |
    perl -nla -F"\t" -e "print for @F" |
    spanr cover stdin -o cover.yml

log_debug Stats of links
echo "key,count" > links.count.csv
for n in 2 3 4-50; do
    linkr filter links.refine.tsv -n ${n} -o stdout \
        > links.copy${n}.tsv

    cat links.copy${n}.tsv |
        perl -nla -F"\t" -e "print for @F" |
        spanr cover stdin -o copy${n}.temp.yml

    wc -l links.copy${n}.tsv |
        perl -nl -e "
            @fields = grep {/\S+/} split /\s+/;
            next unless @fields == 2;
            next unless \$fields[1] =~ /links\.([\w-]+)\.tsv/;
            printf qq{%s,%s\n}, \$1, \$fields[0];
        " \
        >> links.count.csv

    rm links.copy${n}.tsv
done

spanr merge copy2.temp.yml copy3.temp.yml copy4-50.temp.yml -o copy.yml
spanr stat chr.sizes copy.yml --all -o links.copy.csv

fasops mergecsv links.copy.csv links.count.csv --concat -o copy.csv

log_debug Coverage figure
spanr stat chr.sizes cover.yml -o cover.yml.csv
#perl cover_figure.pl --size chr.sizes -f cover.yml

log_info Results for [% id %]

cp cover.yml        ../../Results/[% id %]/[% id %].cover.yml
cp copy.yml         ../../Results/[% id %]/[% id %].copy.yml
mv cover.yml.csv    ../../Results/[% id %]/[% id %].cover.csv
mv copy.csv         ../../Results/[% id %]/[% id %].copy.csv
cp links.refine.tsv ../../Results/[% id %]/[% id %].links.tsv
#mv cover.png        ../../Results/[% id %]/[% id %].cover.png
mv multi.refine.fas ../../Results/[% id %]/[% id %].multi.fas
mv pair.refine.fas  ../../Results/[% id %]/[% id %].pair.fas

log_info Clean up

find . -type f -name "*genome.fa*"   | parallel --no-run-if-empty rm
find . -type f -name "*all.fasta*"   | parallel --no-run-if-empty rm
find . -type f -name "*.sep.fasta"   | parallel --no-run-if-empty rm
find . -type f -name "axt.*"         | parallel --no-run-if-empty rm
find . -type f -name "replace.*.tsv" | parallel --no-run-if-empty rm
find . -type f -name "*.temp.yml"    | parallel --no-run-if-empty rm
find . -type f -name "*.temp.fas"    | parallel --no-run-if-empty rm

popd > /dev/null

fi

[% END -%]

exit;
