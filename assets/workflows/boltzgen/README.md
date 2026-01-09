# BoltzGen: Toward Universal Binder Design

## Summary

From Stark, Hannes, et al. "BoltzGen: Toward Universal Binder Design." bioRxiv, 2025, https://github.com/HannesStark/boltzgen:

> We introduce BoltzGen, an all-atom generative model for designing proteins and peptides across
> all modalities to bind a wide range of biomolecular targets. BoltzGen builds strong structural
> reasoning capabilities about target-binder interactions into its generative design process. This is
> achieved by unifying design and structure prediction, resulting in a single model that also reaches
> state-of-the-art folding performance. BoltzGen’s generation process can be controlled with a flexible
> design specification language over covalent bonds, structure constraints, binding sites, and more.
> We experimentally validate these capabilities in a total of eight diverse wetlab design campaigns
> with functional and affinity readouts across 26 targets. The experiments span binder modalities
> from nanobodies to disulfide-bonded peptides and include targets ranging from disordered proteins
> to small molecules. For instance, we test 15 nanobody and protein binder designs against each
> of nine novel targets with low similarity to any protein with a known bound structure. For both
> binder modalities, this yields nanomolar binders for 66% of targets. We release model weights,
> data, and both inference and training code at: https://github.com/HannesStark/boltzgen.

Note: This is a basic implementation of BoltzGen that only supports the default parameters.