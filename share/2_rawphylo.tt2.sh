[% INCLUDE header.tt2 %]

#----------------------------#
# [% sh %]
#----------------------------#
log_warn [% sh %]

if [ -e Results/[% opt.multiname %].raw.nwk ]; then
    log_info Results/[% opt.multiname %].raw.nwk exists
    exit;
fi

mkdir -p [% opt.multiname %]_raw
mkdir -p Results

#----------------------------#
# maf2fas
#----------------------------#
log_info Convert maf to fas

[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
log_debug "    [% t %]vs[% q %]"
mkdir -p [% opt.multiname %]_raw/[% t %]vs[% q %]

find Pairwise/[% t %]vs[% q %] -name "*.maf" -or -name "*.maf.gz" |
    parallel --no-run-if-empty -j 1 \
        fasops maf2fas {} -o [% opt.multiname %]_raw/[% t %]vs[% q %]/{/}.fas

fasops covers \
    [% opt.multiname %]_raw/[% t %]vs[% q %]/*.fas \
    -n [% t %] -l [% opt.length %] -t 10 \
    -o [% opt.multiname %]_raw/[% t %]vs[% q %].yml

[% END -%]
[% END -%]

[% IF opt.data.size > 2 -%]
#----------------------------#
# Intersect
#----------------------------#
log_info Intersect

spanr compare --op intersect \
[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
    [% opt.multiname %]_raw/[% t %]vs[% q %].yml \
[% END -%]
[% END -%]
    -o stdout |
    spanr span stdin \
        --op excise -n [% opt.length %] \
        -o [% opt.multiname %]_raw/intersect.yml
[% END -%]

#----------------------------#
# Coverage
#----------------------------#
log_info Coverage

spanr merge [% opt.multiname %]_raw/*.yml \
    -o stdout |
    spanr stat \
        [% args.0 %]/chr.sizes \
        stdin \
        --all \
        -o Results/pairwise.coverage.csv

[% IF opt.data.size > 2 -%]
#----------------------------#
# Slicing
#----------------------------#
log_info Slicing with intersect

[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
log_debug "    [% t %]vs[% q %]"
if [ -e [% opt.multiname %]_raw/[% t %]vs[% q %].slice.fas ]; then
    rm [% opt.multiname %]_raw/[% t %]vs[% q %].slice.fas
fi
find [% opt.multiname %]_raw/[% t %]vs[% q %]/ -name "*.fas" -or -name "*.fas.gz" |
    sort |
    parallel --no-run-if-empty --keep-order -j 1 ' \
        fasops slice {} \
            [% opt.multiname %]_raw/intersect.yml \
            -n [% t %] -l [% opt.length %] -o stdout \
            >> [% opt.multiname %]_raw/[% t %]vs[% q %].slice.fas
    '

[% END -%]
[% END -%]

[% END -%]

#----------------------------#
# Joining
#----------------------------#
log_info Joining intersects

log_debug "    fasops join"
fasops join \
[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
    [% opt.multiname %]_raw/[% t %]vs[% q %].slice.fas \
[% END -%]
[% END -%]
    -n [% opt.data.0.name %] \
    -o [% opt.multiname %]_raw/join.raw.fas

echo [% opt.data.0.name %] > [% opt.multiname %]_raw/names.list
[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
echo [% q %] >> [% opt.multiname %]_raw/names.list
[% END -%]
[% END -%]

# Blocks not containing all queries, e.g. Mito, will be omitted
log_debug "    fasops subset"
fasops subset \
    [% opt.multiname %]_raw/join.raw.fas \
    [% opt.multiname %]_raw/names.list \
    --required \
    -o [% opt.multiname %]_raw/join.filter.fas

log_debug "    fasops refine"
fasops refine \
    --msa mafft --parallel [% opt.parallel %] \
    [% opt.multiname %]_raw/join.filter.fas \
    -o [% opt.multiname %]_raw/join.refine.fas

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
    [% opt.multiname %]_raw/join.refine.fas \
    -o Results/[% opt.multiname %].raw.nwk

plotr tree Results/[% opt.multiname %].raw.nwk

[% ELSIF opt.data.size == 3 -%]
echo "(([% opt.data.0.name %],[% opt.data.1.name %]),[% opt.data.2.name %]);" > Results/[% opt.multiname %].raw.nwk

[% ELSE -%]
echo "([% opt.data.0.name %],[% opt.data.1.name %]);" > Results/[% opt.multiname %].raw.nwk

[% END -%]

exit;
