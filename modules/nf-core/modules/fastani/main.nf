// Import generic module functions
include { initOptions; saveFiles } from '../../../../lib/nf/functions'

options     = initOptions(params.options ? params.options : [:], 'fastani')
publish_dir = params.is_subworkflow ? "${params.outdir}/bactopia-tools/${params.wf}/${params.run_name}" : params.outdir

process FASTANI {
    tag "${reference_name}"
    label 'process_medium'
    publishDir "${publish_dir}/${reference_name}", mode: params.publish_dir_mode, overwrite: params.force,
        saveAs: { filename -> saveFiles(filename:filename, opts:options) }

    conda (params.enable_conda ? "bioconda::fastani=1.32" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastani:1.32--he1c1bb9_0' :
        'quay.io/biocontainers/fastani:1.32--he1c1bb9_0' }"


    input:
    tuple val(meta), path(query, stageAs: 'query-tmp/*')
    each path(reference)

    output:
    tuple val(meta), path("*.tsv")          , emit: tsv
    path "*.{stdout.txt,stderr.txt,log,err}", emit: logs, optional: true
    path ".command.*"                       , emit: nf_logs
    path "versions.yml"                     , emit: versions

    script:
    def prefix = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"
    def is_compressed = reference.getName().endsWith(".gz") ? true : false
    reference_fasta = reference.getName().replace(".gz", "")
    reference_name = reference_fasta.replace(".fna", "")
    """
    if [ "$is_compressed" == "true" ]; then
        gzip -c -d $reference > $reference_fasta
    fi

    mkdir query
    cp -P query-tmp/* query/
    find query/ -name "*.gz" | xargs gunzip
    find query/ -name "*" -type f > query-list.txt

    fastANI \\
        --ql query-list.txt \\
        -r $reference_fasta \\
        -o fastani-result.tmp

    echo "query<TAB>reference<TAB>ani<TAB>mapped_fragments<TAB>total_fragments" | sed 's/<TAB>/\t/g' > ${reference_name}.tsv
    sed 's=^query/==' fastani-result.tmp>> ${reference_name}.tsv

    cat <<-END_VERSIONS > versions.yml
    fastani:
        fastani: \$(fastANI --version 2>&1 | sed 's/version//;')
    END_VERSIONS
    """
}