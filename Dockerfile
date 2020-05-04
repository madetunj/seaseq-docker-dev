#################################################################
# Dockerfile
#
# Software:         SEASEQ Pipeline
# Software Version: v1.0.0
# Description:      Dockerized version of SEASEQ Pipeline
# Base Image:       ubuntu:18.04
# Build Cmd:        docker build --rm -t madetunj/seaseq:v1.0.0 .
# Pull Cmd:         docker pull madetunj/seaseq:v1.0.0
# Run Cmd:          docker run --rm -t madetunj/seaseq:v1.0.0
#################################################################
FROM ubuntu:18.04 as builder

#install java and ubuntu dependencies
RUN apt-get update
RUN apt-get --yes install build-essential python3 wget unzip zlib1g-dev
RUN rm -rf /var/lib/apt/lists/*
RUN cp /usr/bin/python3 /usr/bin/python

#install samtools
ENV SAMTOOLS_VERSION 1.9
ENV SAMTOOLS_URL "https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2"
RUN cd /tmp && wget $SAMTOOLS_URL; \
    tar xf samtools-${SAMTOOLS_VERSION}.tar.bz2; \
    cd samtools-${SAMTOOLS_VERSION}; \
    ./configure \
    --prefix /usr/local --disable-bz2 --disable-lzma --without-curses \
    && make -j $(nproc) && make install

#install bedtools
ENV BEDTOOLS_VERSION 2.25.0
ENV BEDTOOLS_URL "https://github.com/arq5x/bedtools2/releases/download/v${BEDTOOLS_VERSION}/bedtools-${BEDTOOLS_VERSION}.tar.gz"
RUN cd /tmp && wget $BEDTOOLS_URL; \
    tar -zxf bedtools-${BEDTOOLS_VERSION}.tar.gz; \
    cd bedtools2; \
    make && make install

#install fastqc
ENV FASTQC_VERSION 0.11.9
ENV FASTQC_URL "https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v${FASTQC_VERSION}.zip"
RUN cd /tmp && wget ${FASTQC_URL}; \
    unzip fastqc_v${FASTQC_VERSION}.zip; \
    chmod 755 FastQC/fastqc;

#install seaseq
ENV SEASEQ_VERSION 2-dev
ENV SEASEQ_URL "https://github.com/madetunj/seaseq-dev/archive/v${SEASEQ_VERSION}.tar.gz"
RUN mkdir -p /tmp/SEASEQ
RUN cd /tmp && wget ${SEASEQ_URL} && tar -xf v${SEASEQ_VERSION}.tar.gz; \
    cp -rf /tmp/seaseq-dev-${SEASEQ_VERSION}/bin /tmp/SEASEQ/bin; \
    cp -rf /tmp/seaseq-dev-${SEASEQ_VERSION}/cwl /tmp/SEASEQ/cwl;

FROM ubuntu:18.04 

#install R
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update \ 
	&& apt-get install -y --no-install-recommends \
	    apt-utils \
		ed \
		less \
		locales \
		vim-tiny \
		wget \
		ca-certificates \
		apt-transport-https \
		gsfonts \
		gnupg2 \
		curl \
	&& rm -rf /var/lib/apt/lists/*

# Configure default locale, see https://github.com/rocker-org/rocker/issues/19
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
	&& locale-gen en_US.utf8 \
	&& /usr/sbin/update-locale LANG=en_US.UTF-8

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

RUN echo "deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/" > /etc/apt/sources.list.d/cran.list

# note the proxy for gpg
RUN curl -sSL 'http://keyserver.ubuntu.com/pks/lookup?op=get&search=0xE084DAB9' | gpg --import
RUN gpg -a --export E084DAB9 | apt-key add -
RUN curl -sSL 'http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x51716619E084DAB9' | gpg --import
RUN gpg -a --export 51716619E084DAB9 | apt-key add -
   
ENV R_BASE_VERSION 3.6.3
LABEL version=3.6.3

# Now install R and littler, and create a link for littler in /usr/local/bin
# Also set a default CRAN repo, and make sure littler knows about it too
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		littler \
        r-cran-littler \
		r-base=${R_BASE_VERSION}* \
		r-base-dev=${R_BASE_VERSION}* \
		r-recommended=${R_BASE_VERSION}* \
        && echo 'options(repos = c(CRAN = "https://cloud.r-project.org/"), download.file.method = "libcurl")' >> /etc/R/Rprofile.site \
        && echo 'source("/etc/R/Rprofile.site")' >> /etc/littler.r \
	&& ln -s /usr/share/doc/littler/examples/install.r /usr/local/bin/install.r \
	&& ln -s /usr/share/doc/littler/examples/install2.r /usr/local/bin/install2.r \
	&& ln -s /usr/share/doc/littler/examples/installGithub.r /usr/local/bin/installGithub.r \
	&& ln -s /usr/share/doc/littler/examples/testInstalled.r /usr/local/bin/testInstalled.r \
	&& install.r docopt \
	&& rm -rf /tmp/downloaded_packages/ /tmp/*.rds \
	&& rm -rf /var/lib/apt/lists/*

#install main base OS dependencies
RUN apt-get update && apt-get install -y build-essential openjdk-11-jdk-headless \
    unzip wget zlib1g-dev python3 nodejs bc python3-numpy python3-scipy python3-pip gawk 
RUN cp /usr/bin/python3 /usr/bin/python
RUN rm -rf /var/lib/apt/lists/*

# install cwl
RUN pip3 install cwlref-runner html5lib

#install toil
RUN pip3 install toil[cwl]

# install Bowtie
ENV BOWTIE_VERSION 1.2.3
ENV BOWTIE_NAME bowtie
ENV BOWTIE_URL "https://github.com/BenLangmead/bowtie/archive/v${BOWTIE_VERSION}.zip"
RUN cd /tmp && apt-get update
RUN cd /tmp && apt-get install -y libtbb-dev && \
    wget $BOWTIE_URL && unzip v${BOWTIE_VERSION}.zip && \
    cd ${BOWTIE_NAME}-${BOWTIE_VERSION} && \
    make -j $(nproc) && make install
RUN rm -rf v${BOWTIE_VERSION}.zip /tmp/${BOWTIE_NAME}-${BOWTIE_VERSION};


RUN mkdir -p /tools
COPY --from=builder /usr/local/bin/samtools /usr/local/bin/samtools
COPY --from=builder /tmp/bedtools2/bin /tools/bedtools/bin
COPY --from=builder /tmp/FastQC /tools/FastQC
COPY --from=builder /tmp/SEASEQ /tools/SEASEQ
ENV PATH /tools/bedtools/bin:/tools/SEASEQ/bin:${PATH}
RUN ln -s /tools/FastQC/fastqc /usr/local/bin/fastqc

ENTRYPOINT ["cwl-runner", "--parallel", "--outdir", "results", "/tools/SEASEQ/cwl/seaseq-mapping.cwl"]
