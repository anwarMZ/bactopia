// Import generic module functions
include { initOptions; saveFiles } from '../../../lib/nf/functions'
options       = initOptions(params.containsKey("options") ? params.options : [:], 'mlst')
options.btype = options.btype ?: "tools"
conda_tools   = "bioconda::mlst=2.23.0"
conda_name    = conda_tools.replace("=", "-").replace(":", "-").replace(" ", "-")
conda_env     = file("${params.condadir}/${conda_name}").exists() ? "${params.condadir}/${conda_name}" : conda_tools

process MLST {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? conda_env : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mlst:2.23.0--hdfd78af_1' :
        'quay.io/biocontainers/mlst:2.23.0--hdfd78af_1' }"

    input:
    tuple val(meta), path(fasta)
    path db

    output:
    tuple val(meta), path("*.tsv"), emit: tsv
    path "*.{log,err}" , emit: logs, optional: true
    path ".command.*"  , emit: nf_logs
    path "versions.yml", emit: versions

    script:
    prefix = options.suffix ? "${options.suffix}" : "${meta.id}"
    """
    tar -xzvf $db

    mlst \\
        --threads $task.cpus \\
        --blastdb mlstdb/blast/mlst.fa \\
        --datadir mlstdb/pubmlst \\
        $options.args \\
        $fasta \\
        > ${prefix}.tsv

    # Cleanup
    rm -rf mlstdb

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mlst: \$( echo \$(mlst --version 2>&1) | sed 's/mlst //' )
        mlst-database: \$( cat mlstdb/DB_VERSION )
    END_VERSIONS
    """
}
