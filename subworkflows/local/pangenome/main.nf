//
// pangenome - Pangenome analysis with optional core-genome phylogeny
//
if (params.use_roary) {
    include { ROARY as PG_TOOL } from '../roary/main' addParams( options: [] )
} else {
    include { PIRATE as PG_TOOL } from '../pirate/main' addParams( options: [publish_to_base: [".aln.gz"]] )
}

include { CLONALFRAMEML } from '../clonalframeml/main' addParams( options: [suffix: 'core-genome', ignore: [".aln.gz"], publish_to_base: [".masked.aln.gz"]] )
include { IQTREE as FINAL_TREE } from '../iqtree/main' addParams( options: [suffix: 'core-genome', ignore: [".aln.gz"], publish_to_base: [".iqtree"]] )
include { SNPDISTS } from '../../../modules/nf-core/modules/snpdists/main' addParams( options: [suffix: 'core-genome.distance', publish_to_base: true] )
include { SCOARY } from '../../../modules/nf-core/modules/scoary/main' addParams( options: [] )
                                                                       
workflow PANGENOME {
    take:
    gff // channel: [ val(meta), [ gff ] ]

    main:
    ch_versions = Channel.empty()
    ch_needs_prokka = Channel.empty()

    // Collect local assemblies
    /*
    if (params.assembly) {
        assemblies = []
        if (file(params.assembly).exists()) {
            if (file(params.assembly).isDirectory()) {
                assemblies_found = file("${params.assembly}/${params.assembly_pattern}")
                if (assemblies_found.size() == 0) {
                    log.error("0 assemblies were found in ${params.assembly} using the pattern ${params.assembly_pattern}, please check. Unable to continue.")
                    exit 1
                } else {
                    assemblies_found.each { assembly ->
                        assemblies << [[id: file(assembly).getSimpleName()], file(assembly).getSimpleName()]
                    }
                }
            } else {
                assemblies << [[id: file(params.assembly).getSimpleName()], file(params.assembly).getSimpleName()]
                is_compressed = params.assembly.endsWith(".gz") ? true : false
                has_assembly = true
            }
        } else {
            log.error("Could not open ${params.assembly}, please verify existence. Unable to continue.")
            exit 1
        }
        log.info("Found ${assemblies.size()} local assemblies.")
    }
    */

    // Create Pangenome
    //gff.collect{meta, gff -> gff}.map{ gff -> [[id: params.use_roary ? 'roary' : 'pirate'], gff]}.set{ ch_merge_gff }
    PG_TOOL(gff)
    ch_versions.mix(PG_TOOL.out.versions)

    // Per-sample SNP distances
    SNPDISTS(PG_TOOL.out.aln)
    ch_versions.mix(SNPDISTS.out.versions)
    
    // Identify Recombination
    if (!params.skip_recombination) {
        // Run ClonalFrameML
        CLONALFRAMEML(PG_TOOL.out.aln)
        ch_versions.mix(CLONALFRAMEML.out.versions)
    }

    // Create core-genome phylogeny
    if (!params.skip_phylogeny) {
        if (params.skip_recombination) {
            FINAL_TREE(PG_TOOL.out.aln)
        } else {
            FINAL_TREE(CLONALFRAMEML.out.masked_aln)
        }
        ch_versions.mix(FINAL_TREE.out.versions)
    }

    // Pan-genome GWAS
    if (params.traits) {
        SCOARY([id:'scoary'], PG_TOOL.out.csv, file(params.traits))
        ch_versions.mix(SCOARY.out.versions)
    }

    emit:
    versions = ch_versions // channel: [ versions.yml ]
}