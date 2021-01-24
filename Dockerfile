FROM linuxbrew/brew
LABEL maintainer="Qiang Wang <wang-q@outlook.com>"

# Build
# docker build -t wangq/egaz .

# Run
# docker run --rm wangq/egaz egaz help

# Github actions
# https://docs.docker.com/ci-cd/github-actions/

RUN true \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        pigz \
        mummer \
        muscle \
        ncbi-blast+ \
        raxml \
        samtools \
        poa

RUN true \
 && export HOMEBREW_NO_ANALYTICS=1 \
 && export HOMEBREW_NO_AUTO_UPDATE=1 \
 && brew install perl \
 && rm -fr $(brew --cache)/* \
 && curl -L https://cpanmin.us | perl - App::cpanminus \
 && chown -R linuxbrew: /home/linuxbrew/.linuxbrew \
 && chmod -R g+w,o-w /home/linuxbrew/.linuxbrew \
 && mkdir -p $HOME/bin \
 && rm -fr /root/.cpan \
 && rm -fr /root/.gem \
 && rm -fr /root/.cpanm

RUN true \
 && export HOMEBREW_NO_ANALYTICS=1 \
 && export HOMEBREW_NO_AUTO_UPDATE=1 \
 && brew install brewsci/bio/lastz \
 && brew install wang-q/tap/faops \
 && brew install wang-q/tap/multiz \
 && rm -fr $(brew --cache)/* \
 && chown -R linuxbrew: /home/linuxbrew/.linuxbrew \
 && chmod -R g+w,o-w /home/linuxbrew/.linuxbrew

# Change this when Perl updated
ENV PATH=/root/bin:/home/linuxbrew/.linuxbrew/Cellar/perl/5.32.0/bin:$PATH

WORKDIR /home/linuxbrew/App-Egaz
ADD . .

RUN true \
 && cpanm -nq --installdeps --with-develop . \
 && cpanm -nq . \
 && perl Build.PL \
 && ./Build build \
 && ./Build test \
 && ./Build install \
 && ./Build clean \
 && rm -fr /root/.cpanm
