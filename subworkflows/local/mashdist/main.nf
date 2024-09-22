//
// mashdist - Calculate Mash distances between sequences
//
ask_merlin = params.containsKey('ask_merlin') ? params.ask_merlin : false
include { initOptions } from '../../../lib/nf/functions'
options = initOptions(params.containsKey("options") ? params.options : [:], 'mashdist')
options.is_module = params.wf == 'mashdist' ? true : false
options.args = [
    "-v ${params.max_p}",
    ask_merlin || params.wf == "merlin" ? "-d ${params.merlin_dist}" : "-d ${params.max_dist}",
    "-w ${params.mash_w}",
    "-m ${params.mash_m}",
    "-S ${params.mash_seed}"
].join(' ').replaceAll("\\s{2,}", " ").trim()
options.ignore = [".fna", ".fna.gz", "fastq.gz", ".genus"]
options.subdir = params.run_name
options.logs_use_prefix = true

MASH_SKETCH = []
if (ask_merlin || params.wf == "merlin") {
    include { MERLIN_DIST as MERLINDIST_MODULE } from '../../../modules/nf-core/mash/dist/main' addParams( options: options )
} else {
    MASH_SKETCH = file(params.mash_sketch)
    include { MASH_DIST as MASHDIST_MODULE  } from '../../../modules/nf-core/mash/dist/main' addParams( options: options )
    include { CSVTK_CONCAT } from '../../../modules/nf-core/csvtk/concat/main' addParams( options: [logs_subdir: 'mashdist-concat', process_name: params.merge_folder] )
}

workflow MASHDIST {
    take:
    seqs // channel: [ val(meta), [ reads or assemblies ] ]

    main:
    ch_versions = Channel.empty()
    ch_merged_mashdist = Channel.empty()

    MASHDIST_MODULE(seqs, MASH_SKETCH)
    ch_versions = ch_versions.mix(MASHDIST_MODULE.out.versions.first())

    MASHDIST_MODULE.out.dist.collect{meta, dist -> dist}.map{ dist -> [[id:'mashdist'], dist]}.set{ ch_merge_mashdist }
    CSVTK_CONCAT(ch_merge_mashdist, 'tsv', 'tsv')
    ch_merged_mashdist = ch_merged_mashdist.mix(CSVTK_CONCAT.out.csv)
    ch_versions = ch_versions.mix(CSVTK_CONCAT.out.versions)

    emit:
    dist = MASHDIST_MODULE.out.dist
    merged_dist = ch_merged_mashdist
    versions = ch_versions // channel: [ versions.yml ]
}

workflow MERLINDIST {
    take:
    seqs // channel: [ val(meta), [ reads or assemblies ] ]
    mash_db // channel: [ mash_db ]

    main:
    ch_versions = Channel.empty()

    MERLINDIST_MODULE(seqs, mash_db)
    ch_versions = ch_versions.mix(MERLINDIST_MODULE.out.versions.first())

    emit:
    dist = MERLINDIST_MODULE.out.dist
    escherichia = MERLINDIST_MODULE.out.escherichia
    escherichia_fq = MERLINDIST_MODULE.out.escherichia_fq
    escherichia_fna_fq = MERLINDIST_MODULE.out.escherichia_fna_fq
    haemophilus = MERLINDIST_MODULE.out.haemophilus
    klebsiella  = MERLINDIST_MODULE.out.klebsiella
    legionella = MERLINDIST_MODULE.out.legionella
    listeria = MERLINDIST_MODULE.out.listeria
    mycobacterium = MERLINDIST_MODULE.out.mycobacterium
    mycobacterium_fq = MERLINDIST_MODULE.out.mycobacterium_fq
    neisseria = MERLINDIST_MODULE.out.neisseria
    pseudomonas = MERLINDIST_MODULE.out.pseudomonas
    salmonella = MERLINDIST_MODULE.out.salmonella
    salmonella_fq = MERLINDIST_MODULE.out.salmonella_fq
    staphylococcus = MERLINDIST_MODULE.out.staphylococcus
    streptococcus  = MERLINDIST_MODULE.out.streptococcus
    streptococcus_fq = MERLINDIST_MODULE.out.streptococcus_fq
    versions = ch_versions // channel: [ versions.yml ]
}
