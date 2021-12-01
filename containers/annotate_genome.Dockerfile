FROM nfcore/base:1.12.1

LABEL base.image="nfcore/base:1.12.1"
LABEL software="Bactopia - annotate_genome"
LABEL software.version="2.0.0"
LABEL description="A flexible pipeline for complete analysis of bacterial genomes"
LABEL website="https://bactopia.github.io/"
LABEL license="https://github.com/bactopia/bactopia/blob/master/LICENSE"
LABEL maintainer="Robert A. Petit III"
LABEL maintainer.email="robert.petit@emory.edu"
LABEL conda.env="bactopia/conda/linux/annotate_genome.yml"
LABEL conda.md5="2da4b81e55d1a8713f3bc7e39f20fcc8"

COPY conda/linux/annotate_genome.yml /
RUN conda env create -q -f annotate_genome.yml && conda clean -y -a 
ENV PATH /opt/conda/envs/bactopia-annotate_genome/bin:$PATH
