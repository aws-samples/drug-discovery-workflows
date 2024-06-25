import torch

import esm.utils.constants.esm3 as C
from esm.models.function_decoder import FunctionTokenDecoder
from esm.models.vqvae import StructureTokenDecoder
from esm.tokenization.function_tokenizer import (
    InterProQuantizedTokenizer,
)
from esm.tokenization.residue_tokenizer import (
    ResidueAnnotationsTokenizer,
)
from esm.tokenization.sasa_tokenizer import (
    SASADiscretizingTokenizer,
)
from esm.tokenization.sequence_tokenizer import (
    EsmSequenceTokenizer,
)
from esm.tokenization.ss_tokenizer import (
    SecondaryStructureTokenizer,
)
from esm.tokenization.structure_tokenizer import (
    StructureTokenizer,
)
from esm.utils.function.encode_decode import (
    decode_function_tokens,
    decode_residue_annotation_logits,
)
from esm.utils.structure.protein_chain import ProteinChain
from esm.utils.types import FunctionAnnotation


def decode_sequence(
    sequence_tokens: torch.Tensor,
    sequence_tokenizer: EsmSequenceTokenizer,
    **kwargs,
) -> str:
    if sequence_tokens[0] != sequence_tokenizer.cls_token_id:
        raise ValueError(
            f"Sequence does not start with BOS token '{sequence_tokenizer.cls_token_id}': {sequence_tokens}"
        )
    if sequence_tokens[-1] != sequence_tokenizer.eos_token_id:
        raise ValueError(
            f"Sequence does not end with EOS token '{sequence_tokenizer.eos_token_id}': {sequence_tokens}"
        )

    sequence = sequence_tokenizer.decode(
        sequence_tokens,
        **kwargs,
    )
    sequence = sequence.replace(" ", "")
    sequence = sequence.replace(sequence_tokenizer.mask_token, C.MASK_STR_SHORT)
    sequence = sequence.replace(sequence_tokenizer.cls_token, "")
    sequence = sequence.replace(sequence_tokenizer.eos_token, "")

    return sequence


def decode_structure(
    structure_tokens: torch.Tensor,
    structure_decoder: StructureTokenDecoder,
    structure_tokenizer: StructureTokenizer,
    sequence: str | None = None,
) -> tuple[torch.Tensor, torch.Tensor]:
    is_singleton = len(structure_tokens.size()) == 1
    if is_singleton:
        structure_tokens = structure_tokens.unsqueeze(0)
    else:
        raise ValueError(
            f"Only one structure can be decoded at a time, got structure tokens of shape {structure_tokens.size()}"
        )

    if structure_tokens[0, 0] != structure_tokenizer.bos_token_id:
        raise ValueError(
            f"Structure does not start with BOS token '{structure_tokenizer.bos_token_id}': {structure_tokens}"
        )
    if structure_tokens[0, -1] != structure_tokenizer.eos_token_id:
        raise ValueError(
            f"Structure does not end with EOS token '{structure_tokenizer.eos_token_id}': {structure_tokens}"
        )

    decoder_output = structure_decoder.decode(
        structure_tokens,
    )
    bb_coords: torch.Tensor = decoder_output["bb_pred"][
        0, 1:-1, ...
    ]  # Remove BOS and EOS tokens
    bb_coords = bb_coords.detach().cpu()

    plddt: torch.Tensor = decoder_output["plddt"][0, 1:-1]
    plddt = plddt.detach().cpu()

    # TODO: Check if infer_oxygen is necessary
    chain = ProteinChain.from_backbone_atom_coordinates(bb_coords, sequence=sequence)
    chain = chain.infer_oxygen()
    return torch.tensor(chain.atom37_positions), plddt


def decode_secondary_structure(
    secondary_structure_tokens: torch.Tensor,
    ss_tokenizer: SecondaryStructureTokenizer,
) -> str:
    if secondary_structure_tokens[0] != ss_tokenizer.bos_token_id:
        raise ValueError(
            f"Secondary structure does not start with BOS token '{ss_tokenizer.bos_token_id}': {secondary_structure_tokens}"
        )
    if secondary_structure_tokens[-1] != ss_tokenizer.eos_token_id:
        raise ValueError(
            f"Secondary structure does not end with EOS token '{ss_tokenizer.eos_token_id}': {secondary_structure_tokens}"
        )
    secondary_structure_tokens = secondary_structure_tokens[1:-1]

    secondary_structure = ss_tokenizer.decode(
        secondary_structure_tokens,
    )
    return secondary_structure


def decode_sasa(
    sasa_tokens: torch.Tensor,
    sasa_tokenizer: SASADiscretizingTokenizer,
) -> list[str]:
    if sasa_tokens[0] != sasa_tokenizer.bos_token_id:
        raise ValueError(
            f"SASA does not start with BOS token '{sasa_tokenizer.bos_token_id}': {sasa_tokens}"
        )
    if sasa_tokens[-1] != sasa_tokenizer.eos_token_id:
        raise ValueError(
            f"SASA does not end with EOS token '{sasa_tokenizer.eos_token_id}': {sasa_tokens}"
        )
    sasa_tokens = sasa_tokens[1:-1]

    sasa = sasa_tokenizer.decode(
        sasa_tokens,
    )
    sasa = sasa.split(",")
    return sasa


def decode_function_annotations(
    function_annotation_tokens: torch.Tensor,
    function_token_decoder: FunctionTokenDecoder,
    function_tokenizer: InterProQuantizedTokenizer,
    **kwargs,
) -> list[FunctionAnnotation]:
    # No need to check for BOS/EOS as function annotations are not affected

    function_annotations = decode_function_tokens(
        function_annotation_tokens,
        function_token_decoder=function_token_decoder,
        function_tokens_tokenizer=function_tokenizer,
        **kwargs,
    )
    return function_annotations


def decode_residue_annotations(
    residue_annotation_logits: torch.Tensor,
    residue_annotation_decoder: ResidueAnnotationsTokenizer,
) -> list[FunctionAnnotation]:
    # No need to check for BOS/EOS as function annotations are not affected

    residue_annotations = decode_residue_annotation_logits(
        residue_annotation_logits,
        residue_annotations_tokenizer=residue_annotation_decoder,
    )
    return residue_annotations
