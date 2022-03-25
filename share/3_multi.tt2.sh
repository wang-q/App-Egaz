[% INCLUDE header.tt2 %]

#----------------------------#
# [% sh %]
#----------------------------#
log_warn [% sh %]

if [ -e Results/[% opt.multiname %].nwk ]; then
    log_info Results/[% opt.multiname %].nwk exists
    exit;
fi

if [ -d [% opt.multiname %]_mz ]; then
    rm -fr [% opt.multiname %]_mz;
fi;
mkdir -p [% opt.multiname %]_mz

if [ -d [% opt.multiname %]_fasta ]; then
    rm -fr [% opt.multiname %]_fasta;
fi;
mkdir -p [% opt.multiname %]_fasta

if [ -d [% opt.multiname %]_refined ]; then
    rm -fr [% opt.multiname %]_refined;
fi;
mkdir -p [% opt.multiname %]_refined

mkdir -p Results

#----------------------------#
# mz
#----------------------------#
log_info multiz

[% IF opt.tree -%]
egaz multiz \
[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
    Pairwise/[% t %]vs[% q %] \
[% END -%]
[% END -%]
    --tree [% opt.tree %] \
    -o [% opt.multiname %]_mz \
    --parallel [% opt.parallel %]

[% ELSIF opt.order %]
egaz multiz \
[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
    Pairwise/[% t %]vs[% q %] \
[% END -%]
[% END -%]
    --tree fake_tree.nwk \
    -o [% opt.multiname %]_mz \
    --parallel [% opt.parallel %]

[% ELSE %]
if [ -f Results/[% opt.multiname %].raw.nwk ]; then
    egaz multiz \
[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
        Pairwise/[% t %]vs[% q %] \
[% END -%]
[% END -%]
        --tree Results/[% opt.multiname %].raw.nwk \
        -o [% opt.multiname %]_mz \
        --parallel [% opt.parallel %]

else
    egaz multiz \
[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
        Pairwise/[% t %]vs[% q %] \
[% END -%]
[% END -%]
        --tree fake_tree.nwk \
        -o [% opt.multiname %]_mz \
        --parallel [% opt.parallel %]

fi
[% END -%]

find [% opt.multiname %]_mz -type f -name "*.maf" |
    parallel --no-run-if-empty -j 2 pigz -p [% opt.parallel2 %] {}

#----------------------------#
# maf2fas
#----------------------------#
log_info Convert maf to fas
find [% opt.multiname %]_mz -name "*.maf" -or -name "*.maf.gz" |
    parallel --no-run-if-empty -j [% opt.parallel %] \
        fasops maf2fas {} -o [% opt.multiname %]_fasta/{/}.fas

#----------------------------#
# refine fasta
#----------------------------#
log_info Refine fas
find [% opt.multiname %]_fasta -name "*.fas" -or -name "*.fas.gz" |
    parallel --no-run-if-empty -j 2 '
        fasops refine \
            --msa [% opt.msa %] --parallel [% opt.parallel2 %] \
            --quick --pad 100 --fill 100 \
[% IF opt.outgroup -%]
            --outgroup \
[% END -%]
            {} \
            -o [% opt.multiname %]_refined/{/}
    '

find [% opt.multiname %]_refined -type f -name "*.fas" |
    parallel --no-run-if-empty -j 2 pigz -p [% opt.parallel2 %] {}

#----------------------------#
# RAxML
#----------------------------#
[% IF opt.data.size > 3 -%]
log_info RAxML

egaz raxml \
    --parallel [% IF opt.parallel > 3 %] [% opt.parallel - 1 %] [% ELSE %] 2 [% END %] \
[% IF opt.outgroup -%]
    --outgroup [% opt.outgroup %] \
[% END -%]
[% IF opt.verbose -%]
    -v \
[% END -%]
    [% opt.multiname %]_refined/*.fas.gz \
    -o Results/[% opt.multiname %].nwk

plotr tree Results/[% opt.multiname %].nwk

[% ELSIF opt.data.size == 3 -%]
echo "(([% opt.data.0.name %],[% opt.data.1.name %]),[% opt.data.2.name %]);" > Results/[% opt.multiname %].nwk

[% ELSE -%]
echo "([% opt.data.0.name %],[% opt.data.1.name %]);" > Results/[% opt.multiname %].nwk

[% END -%]

exit;
