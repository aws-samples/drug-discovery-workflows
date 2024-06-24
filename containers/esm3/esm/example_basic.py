from esm.models.esm3 import ESM3
from esm.sdk.api import (
    ESM3InferenceClientV1,
    ESMProtein,
    GenerationConfig,
    SamplingConfig,
    SamplingTrackConfig,
)
from esm.utils.types import FunctionAnnotation


def get_sample_protein() -> ESMProtein:
    protein = ESMProtein.from_pdb("esm/data/1utn.pdb")
    protein.function_annotations = [
        # Peptidase S1A, chymotrypsin family: https://www.ebi.ac.uk/interpro/structure/PDB/1utn/
        FunctionAnnotation(label="peptidase", start=100, end=114),
        FunctionAnnotation(label="chymotrypsin", start=190, end=202),
    ]
    return protein


if __name__ == "__main__":
    esm3: ESM3InferenceClientV1 = ESM3.from_pretrained("esm3_open_small")

    # Single step decoding
    protein = get_sample_protein()
    protein.function_annotations = None
    protein = esm3.encode(protein)
    single_step_protein = esm3.forward_and_sample(
        protein, SamplingConfig(structure=SamplingTrackConfig(topk_logprobs=2))
    )
    single_step_protein = esm3.decode(single_step_protein.protein_tensor)
    print(single_step_protein.function_annotations)
