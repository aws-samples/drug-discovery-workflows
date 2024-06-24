from typing import Sequence

import torch

from esm.models.function_decoder import (
    FunctionTokenDecoder,
    _merge_annotations,
)
from esm.tokenization.function_tokenizer import (
    InterProQuantizedTokenizer,
)
from esm.tokenization.residue_tokenizer import (
    ResidueAnnotationsTokenizer,
)
from esm.utils.types import FunctionAnnotation


def encode_function_annotations(
    sequence: str,
    function_annotations: Sequence[FunctionAnnotation],
    function_tokens_tokenizer: InterProQuantizedTokenizer,
    residue_annotations_tokenizer: ResidueAnnotationsTokenizer,
    add_special_tokens: bool = True,
) -> tuple[torch.Tensor, torch.Tensor]:
    assert isinstance(
        residue_annotations_tokenizer, ResidueAnnotationsTokenizer
    ), "residue_annotations_tokenizer must be of type ResidueAnnotationsTokenizer"

    # Split the user's annotations by type
    ft_annotations: list[FunctionAnnotation] = []
    ra_annotations: list[FunctionAnnotation] = []
    for fa in function_annotations:
        assert (
            1 <= fa.start <= fa.end <= len(sequence)
        ), f"Invalid (start, end) in function annotation {fa}. Indices 1-indexed and [inclusive, inclusive]"

        supported_label = False

        # Is it a function keyword?
        if fa.label in function_tokens_tokenizer._tfidf_model.vocabulary_:
            ft_annotations.append(fa)
            supported_label = True

        # Is it a residue annotation?
        if fa.label in residue_annotations_tokenizer._labels:
            ra_annotations.append(fa)
            supported_label = True

        if not supported_label:
            raise ValueError(f"Unknown label in FunctionAnnotation: {fa.label}")

    # Convert function token FunctionAnnotations -> Tensor
    function_tokens = function_tokens_tokenizer.tokenize(
        annotations=ft_annotations,
        seqlen=len(sequence),
    )
    function_token_ids = function_tokens_tokenizer.encode(
        function_tokens, add_special_tokens=add_special_tokens
    )

    # Convert residue annotation FunctionAnnotations -> Tensor
    if ra_annotations:
        descriptions, starts, ends = zip(*ra_annotations)
    else:
        descriptions = starts = ends = None
    ra_tokens = residue_annotations_tokenizer.tokenize(
        {
            "interpro_site_descriptions": descriptions,
            "interpro_site_starts": starts,
            "interpro_site_ends": ends,
        },
        sequence=sequence,
        fail_on_mismatch=True,
    )
    residue_annotation_ids = residue_annotations_tokenizer.encode(
        ra_tokens, add_special_tokens=add_special_tokens
    )

    return function_token_ids, residue_annotation_ids


def decode_function_tokens(
    function_token_ids: torch.Tensor,
    function_token_decoder: FunctionTokenDecoder,
    function_tokens_tokenizer: InterProQuantizedTokenizer,
    decoder_annotation_threshold: float = 0.1,
    annotation_min_length: int | None = 5,
    annotation_gap_merge_max: int | None = 3,
) -> list[FunctionAnnotation]:
    """Decodes model prediction logits into function predictions.

    Merges function token and residue annotation predictions into a single
    set of FunctionAnnotation predictions.

    Args:
        function_token_ids: Tensor <float>[length, depth] of
            function token ids.
        residue_annotation_logits: Tensor  <float>[length, RA-vocab] of residue
            annotation binary classification logits.
        function_tokens_tokenizer: InterPro annotation tokenizer.
        residue_annotation_threshold: tokenizer of residue annotations.
        residue_annotation_threshold: predicted probability threshold for emitting
            a predicted residue annotation.
    Returns:
        Predicted function annotations merged from both predictions.
    """
    assert (
        function_token_ids.ndim == 2
    ), "function_token_ids must be of shape (length, depth)"

    annotations: list[FunctionAnnotation] = []

    # Function Annotations from predicted function tokens.
    decoded = function_token_decoder.decode(
        function_token_ids,
        tokenizer=function_tokens_tokenizer,
        annotation_threshold=decoder_annotation_threshold,
        annotation_min_length=annotation_min_length,
        annotation_gap_merge_max=annotation_gap_merge_max,
    )

    # Convert predicted InterPro annotation to FunctionAnnotation.
    for annotation in decoded["interpro_annotations"]:
        annotation: FunctionAnnotation
        annotation_name = function_tokens_tokenizer.interpro_.lookup_name(
            annotation.label
        )
        if annotation_name is not None:
            label = f"{annotation.label}: {annotation_name}"
        else:
            label = annotation.label
        annotations.append(
            FunctionAnnotation(
                label=label,
                start=annotation.start + 1,  # 0-idx -> 1-idx
                end=annotation.end + 1 - 1,  # 0-idx-excl -> 1-ind-incl
            )
        )

    return annotations


def decode_residue_annotation_logits(
    logits: torch.Tensor,
    residue_annotations_tokenizer: ResidueAnnotationsTokenizer,
    threshold: float = 0.5,
    annotation_min_length: int | None = 5,
    annotation_gap_merge_max: int | None = 3,
) -> list[FunctionAnnotation]:
    """Decodes residue annotation logits into FunctionAnnotations.

    Args:
        logits: Tensor <float>[length, vocab] of residue annotation logits.
        residue_annotations_tokenizer: Tokenizer of residue annotations.
        threshold: predicted probability threshold for emitting a predicted residue
            annotation.
    Returns:
        Predicted residue annotations.
    """
    assert logits.ndim == 2, "logits must be of shape (length, vocab)"

    annotations: list[FunctionAnnotation] = []

    residue_annotations_preds = torch.sigmoid(logits) >= threshold

    for loc, vocab_index in torch.nonzero(residue_annotations_preds).cpu().numpy():
        label = residue_annotations_tokenizer.vocabulary[vocab_index]
        if label not in [*residue_annotations_tokenizer.special_tokens, "<none>"]:
            annotation = FunctionAnnotation(label=label, start=loc, end=loc)
            annotations.append(annotation)

    annotations = _merge_annotations(
        annotations,
        merge_gap_max=annotation_gap_merge_max,
    )

    # Drop very small annotations.
    if annotation_min_length is not None:
        annotations = [
            annotation
            for annotation in annotations
            if annotation.end - annotation.start + 1 >= annotation_min_length
        ]

    return annotations
