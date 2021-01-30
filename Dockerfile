FROM linuxbrew/brew
LABEL maintainer="Qiang Wang <wang-q@outlook.com>"

# Build
# docker build -t wangq/egaz .

# Run
# docker run --rm wangq/egaz:master egaz help
# docker run --rm wangq/egaz:master bash share/check_dep.sh

# Github actions
# https://docs.docker.com/ci-cd/github-actions/

RUN true \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        pigz \
        ncbi-blast+ \
        raxml \
        samtools \
        poa

# Perl
RUN true \
 && export HOMEBREW_NO_ANALYTICS=1 \
 && export HOMEBREW_NO_AUTO_UPDATE=1 \
 && brew install perl \
 && rm -fr $(brew --cache)/* \
 && curl -L https://cpanmin.us | perl - App::cpanminus \
 && rm -fr $(brew --cache)/* \
 && chown -R linuxbrew: /home/linuxbrew/.linuxbrew \
 && chmod -R g+w,o-w /home/linuxbrew/.linuxbrew \
 && mkdir -p $HOME/bin \
 && rm -fr /root/.cpan \
 && rm -fr /root/.gem \
 && rm -fr /root/.cpanm

# Brew packages
RUN true \
 && export HOMEBREW_NO_ANALYTICS=1 \
 && export HOMEBREW_NO_AUTO_UPDATE=1 \
 && brew install mafft \
 && brew install bcftools \
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

# Change this when Perl updated
ENV PATH=/root/bin:/home/linuxbrew/.linuxbrew/Cellar/perl/5.32.1/bin:$PATH

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
 && rm -fr /root/.cpanm
