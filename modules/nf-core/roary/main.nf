// Import generic module functions
include { initOptions; saveFiles } from '../../../lib/nf/functions'
options       = initOptions(params.containsKey("options") ? params.options : [:], 'roary')
options.btype = options.btype ?: "comparative"
conda_tools   = "bioconda::roary=3.13.0"
conda_name    = conda_tools.replace("=", "-").replace(":", "-").replace(" ", "-")
conda_env     = file("${params.condadir}/${conda_name}").exists() ? "${params.condadir}/${conda_name}" : conda_tools

process ROARY {
    tag "$meta.id"
    label 'process_high'
    label 'process_long'

    conda (params.enable_conda ? conda_env : null)
    container "${ workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/roary:3.13.0--pl526h516909a_0' :
        'quay.io/biocontainers/roary:3.13.0--pl526h516909a_0' }"

    input:
    tuple val(meta), path(gff, stageAs: 'gff-tmp/*')

    output:
    tuple val(meta), path("results/*")                        , emit: results
    tuple val(meta), path("core-genome.aln.gz")               , emit: aln, optional: true
    tuple val(meta), path("results/gene_presence_absence.csv"), emit: csv, optional: true
    path "*.{log,err}", emit: logs, optional: true
    path ".command.*", emit: nf_logs
    path "versions.yml", emit: versions

    script:
    prefix = options.suffix ? "${options.suffix}" : "${meta.id}"
    """
    mkdir gff
    cp -L gff-tmp/* gff/
    find gff/ -name "*.gff.gz" | xargs gunzip
    roary \\
        $options.args \\
        -p $task.cpus \\
        -f results/ \\
        gff/*.gff

    gzip results/*.aln
    gzip results/*.fa

    if [[ -f "results/core_gene_alignment.aln.gz" ]]; then
        cp results/core_gene_alignment.aln.gz ./core-genome.aln.gz
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        roary: \$( roary --version )
    END_VERSIONS
    """
}
