//
// assembler - Assembly of Illumina and ONT reads
//
include { initOptions } from '../../../lib/nf/functions'
options = initOptions(params.containsKey("options") ? params.options : [:], 'assembler')
options.is_module = params.wf == 'assembler' ? true : false
options.is_main = true

// args -> Shovill
options.args = [
    "--assembler ${params.shovill_assembler}",
    params.shovill_opts  ? "--opts '${params.shovill_opts}'" : "",
    params.shovill_kmers ? "--kmers '${params.shovill_kmers}'" : "",
    params.no_stitch ? "--nostitch" : "",
    params.no_corr ? "--nocorr" : "",
    "--minlen ${params.min_contig_len}",
    "--mincov ${params.min_contig_cov}",
    "--force",
    "--keepfiles",
    "--depth 0",
    "--noreadcorr"
].join(' ').replaceAll("\\s{2,}", " ").trim()

// args2 -> Dragonflye
options.args2 = [
    "--assembler ${params.dragonflye_assembler}",
    params.dragonflye_opts  ? "--opts '${params.dragonflye_opts}'" : "",
    params.no_polish ? "--nopolish" : "",
    params.medaka_model ? "--model ${params.medaka_model}" : "",
    params.pilon_rounds ? "--pilon ${params.pilon_rounds}" : "",
    "--minlen ${params.min_contig_len}",
    "--mincov ${params.min_contig_cov}",
    "--force",
    "--keepfiles",
    "--depth 0",
    "--minreadlen 0",
    "--minquality 0",
    "--racon ${params.racon_steps}",
    "--medaka ${params.medaka_steps}",
    "--noreadcorr"
].join(' ').replaceAll("\\s{2,}", " ").trim()

// args3 -> Unicycler
options.args3 = [
    params.no_miniasm ? "--no_miniasm" : "",
    params.no_rotate ? "--no_rotate" : "",
    params.keep_all_files ? "--keep 3" : "--keep 1",
    "--min_fasta_length ${params.min_contig_len}",
    "--mode ${params.unicycler_mode}",
    "--min_component_size ${params.min_component_size}",
    "--min_dead_end_size ${params.min_dead_end_size}"
].join(' ').replaceAll("\\s{2,}", " ").trim()

include { ASSEMBLER as ASSEMBLER_MODULE } from '../../../modules/local/bactopia/assembler/main' addParams( options: options )
include { CSVTK_CONCAT } from '../../../modules/nf-core/csvtk/concat/main' addParams( options: [process_name: "assembler"] )

workflow ASSEMBLER {
    take:
    reads // channel: [ val(meta), [ reads ] ]

    main:
    ch_versions = Channel.empty()
    ch_merged_stats = Channel.empty()

    // Assemble genomes
    ASSEMBLER_MODULE(reads)
    ch_versions = ch_versions.mix(ASSEMBLER_MODULE.out.versions)

    // Merge summary of assemblies
    ASSEMBLER_MODULE.out.tsv.collect{meta, tsv -> tsv}.map{ tsv -> [[id:'assembly-scan'], tsv]}.set{ ch_merge_stats }
    CSVTK_CONCAT(ch_merge_stats, 'tsv', 'tsv')
    ch_merged_stats = ch_merged_stats.mix(CSVTK_CONCAT.out.csv)
    ch_versions = ch_versions.mix(CSVTK_CONCAT.out.versions)

    emit:
    fna = ASSEMBLER_MODULE.out.fna
    fna_fastq = ASSEMBLER_MODULE.out.fna_fastq
    tsv = ASSEMBLER_MODULE.out.tsv
    merged_tsv = ch_merged_stats
    versions = ch_versions // channel: [ versions.yml ]
}
