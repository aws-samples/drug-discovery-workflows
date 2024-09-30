from esm.sdk.api import (
    ESM3InferenceClientV1,
    ESMProtein,
)
from esm.utils.types import FunctionAnnotation
from esm3_neuron import ESM3Neuron
import os
import torch
import torch_neuronx


def get_sample_protein() -> ESMProtein:
    protein = ESMProtein.from_pdb("esm/data/1utn.pdb")
    protein.function_annotations = [
        # Peptidase S1A, chymotrypsin family: https://www.ebi.ac.uk/interpro/structure/PDB/1utn/
        FunctionAnnotation(label="peptidase", start=100, end=114),
        FunctionAnnotation(label="chymotrypsin", start=190, end=202),
    ]
    return protein


if __name__ == "__main__":
    print("#" * 76)

    os.environ['NEURON_CC_FLAGS'] = "-O1"

    print("Loading model")
    esm3: ESM3InferenceClientV1 = ESM3Neuron.from_pretrained("esm3_open_small")

    print("Processing input data")
    protein = get_sample_protein()
    protein.function_annotations = None
    protein = esm3.encode(protein)

    protein.sequence = protein.sequence.unsqueeze(0)
    protein.sasa = protein.sasa.unsqueeze(0)
    protein.coordinates = protein.coordinates.unsqueeze(0)

    print("Running CPU inference")
    single_step_protein = esm3.forward(
        sequence_tokens=protein.sequence,
        structure_tokens=None,
        ss8_tokens=None,
        sasa_tokens=protein.sasa,
        function_tokens=None,
        residue_annotation_tokens=None,
        average_plddt=None,
        per_res_plddt=None,
        structure_coords=protein.coordinates,
        chain_id=None,
        sequence_id=None,
    )
    print(
        f"CPU inference complete. Sequence logits output shape is {single_step_protein[0].shape}"
    )
    print("Tracing for AWS Neuron inference")
    traced_model = torch_neuronx.trace(
        esm3,
        (
            protein.sequence,
            None,
            None,
            protein.sasa,
            None,
            None,
            None,
            None,
            protein.coordinates,
            None,
            None,
        ),
    )
    print("Saving traced model")
    torch.jit.save(traced_model, "esm3_neuron.pt")
