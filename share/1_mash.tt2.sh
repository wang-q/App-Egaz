[% INCLUDE header.tt2 %]

#----------------------------#
# [% sh %]
#----------------------------#
log_warn [% sh %]

mkdir -p mash
cd mash

log_info mash sketch
[% FOREACH item IN opt.data -%]
if [[ ! -e [% item.name %].msh ]]; then
    cat [% item.dir %]/chr.fasta |
        mash sketch -k 21 -s 100000 -p [% opt.parallel %] - -I "[% item.name %]" -o [% item.name %]
fi

[% END -%]

log_info mash triangle
mash triangle -E -p [% opt.parallel %] -l <(
    cat ../genome.lst | parallel echo "{}.msh"
    ) \
    > dist.tsv
