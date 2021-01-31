FROM linuxbrew/brew
LABEL maintainer="Qiang Wang <wang-q@outlook.com>"

# Build
# docker build -t wangq/egaz .

# Run
# docker run --rm wangq/egaz:master egaz help
# docker run --rm wangq/egaz:master bash share/check_dep.sh

# Github actions
# https://docs.docker.com/ci-cd/github-actions/

# Change this when Perl updated
ENV PATH=/root/bin:/home/linuxbrew/.linuxbrew/Cellar/perl/5.32.1/bin:$PATH

RUN true \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        raxml \
        poa

# Perl
RUN true \
 && export HOMEBREW_NO_ANALYTICS=1 \
 && export HOMEBREW_NO_AUTO_UPDATE=1 \
 && brew install perl \
 && curl -L https://cpanmin.us | perl - App::cpanminus \
 && rm -fr $(brew --cache)/* \
 && chown -R linuxbrew: /home/linuxbrew/.linuxbrew \
 && chmod -R g+w,o-w /home/linuxbrew/.linuxbrew \
 && rm -fr /root/.cpan \
 && rm -fr /root/.gem \
 && rm -fr /root/.cpanm

# Brew packages
RUN true \
 && export HOMEBREW_NO_ANALYTICS=1 \
 && export HOMEBREW_NO_AUTO_UPDATE=1 \
 && brew install bcftools \
 && brew install mafft \
 && brew install parallel \
 && brew install pigz \
 && brew install samtools \
 && brew install brewsci/bio/circos \
 && brew install brewsci/bio/lastz \
 && brew install brewsci/bio/muscle \
 && brew install brewsci/bio/fasttree \
 && brew install brewsci/bio/snp-sites \
 && brew install wang-q/tap/faops \
 && brew install wang-q/tap/sparsemem \
 && brew install wang-q/tap/multiz \
 && brew install wang-q/tap/intspan \
 && rm -fr $(brew --cache)/* \
 && chown -R linuxbrew: /home/linuxbrew/.linuxbrew \
 && chmod -R g+w,o-w /home/linuxbrew/.linuxbrew

# HOME bin
RUN true \
 && mkdir -p $HOME/bin \
 && curl -L https://github.com/wang-q/ubuntu/releases/download/20190906/jkbin-egaz-ubuntu-1404-2011.tar.gz | \
    tar -xvzf - \
 && mv x86_64/* $HOME/bin/

# RepeatMasker
# https://stackoverflow.com/questions/57629010/linuxbrew-curl-certificate-issue
RUN true \
 && export HOMEBREW_NO_ANALYTICS=1 \
 && export HOMEBREW_NO_AUTO_UPDATE=1 \
 && export HOMEBREW_DEVELOPER=1 \
 && export HOMEBREW_CURLRC=1 \
 && echo "--ciphers DEFAULT@SECLEVEL=1" >> $HOME/.curlrc \
 && brew install brewsci/bio/trf \
 && brew install blast \
 && brew install hmmer \
 && brew install brewsci/bio/rmblast \
 && brew install brewsci/bio/repeatmasker --build-from-source \
 && rm -fr $(brew --prefix)/opt/repeatmasker/libexec/lib/perl5/x86_64-linux-thread-multi/ \
 && rm $(brew --prefix)/opt/repeatmasker/libexec/Libraries/RepeatMasker.lib* \
 && rm $(brew --prefix)/opt/repeatmasker/libexec/Libraries/DfamConsensus.embl \
 && cd $(brew --prefix)/Cellar/$(brew list --versions repeatmasker | sed 's/ /\//')/libexec \
 && curl -L https://github.com/egateam/egavm/releases/download/20170907/repeatmaskerlibraries-20140131.tar.gz | \
    tar -xvzf - \
 && sed -i".bak" 's/\/usr\/bin\/perl/env/' configure.input \
 && ./configure < configure.input \
 && rm -f $(brew --prefix)/bin/rmOutToGFF3.pl \
 && sed -i".bak" 's/::Bin/::RealBin/' $(brew --prefix)/Cellar/$(brew list --versions repeatmasker | sed 's/ /\//')/libexec/util/rmOutToGFF3.pl \
 && ln -s $(brew --prefix)/Cellar/$(brew list --versions repeatmasker | sed 's/ /\//')/libexec/util/rmOutToGFF3.pl $(brew --prefix)/bin/rmOutToGFF3.pl \
 && rm -fr $(brew --cache)/* \
 && chown -R linuxbrew: /home/linuxbrew/.linuxbrew \
 && chmod -R g+w,o-w /home/linuxbrew/.linuxbrew

# R
RUN true \
 && export HOMEBREW_NO_ANALYTICS=1 \
 && export HOMEBREW_NO_AUTO_UPDATE=1 \
 && brew install r \
 && Rscript -e 'install.packages("extrafont", repos="https://mirrors.tuna.tsinghua.edu.cn/CRAN")' \
 && Rscript -e 'install.packages("VennDiagram", repos="https://mirrors.tuna.tsinghua.edu.cn/CRAN")' \
 && Rscript -e 'install.packages("ggplot2", repos="https://mirrors.tuna.tsinghua.edu.cn/CRAN")' \
 && Rscript -e 'install.packages("scales", repos="https://mirrors.tuna.tsinghua.edu.cn/CRAN")' \
 && Rscript -e 'install.packages("gridExtra", repos="https://mirrors.tuna.tsinghua.edu.cn/CRAN")' \
 && Rscript -e 'install.packages("readr", repos="https://mirrors.tuna.tsinghua.edu.cn/CRAN")' \
 && Rscript -e 'install.packages("ape", repos="https://mirrors.tuna.tsinghua.edu.cn/CRAN")' \
 && Rscript -e 'library(extrafont); font_import(prompt = FALSE); fonts();' \
 && rm -fr $(brew --cache)/* \
 && chown -R linuxbrew: /home/linuxbrew/.linuxbrew \
 && chmod -R g+w,o-w /home/linuxbrew/.linuxbrew


WORKDIR /home/linuxbrew/App-Egaz
ADD . .

RUN true \
 && cpanm -nq https://github.com/wang-q/App-Plotr.git \
 && cpanm -nq --installdeps --with-develop . \
 && cpanm -nq . \
 && perl Build.PL \
 && ./Build build \
 && ./Build test \
 && ./Build install \
 && ./Build clean \
 && rm -fr /root/.cpanm \
 && chown -R linuxbrew: /home/linuxbrew/.linuxbrew \
 && chmod -R g+w,o-w /home/linuxbrew/.linuxbrew
