"""Function Token Decoder."""

import json
from collections import defaultdict
from dataclasses import dataclass
from functools import cached_property

import pandas as pd
import torch
import torch.nn as nn
import torch.nn.functional as F

from esm.layers.regression_head import RegressionHead
from esm.layers.transformer_stack import TransformerStack
from esm.tokenization.function_tokenizer import (
    InterProQuantizedTokenizer,
)
from esm.utils.constants import esm3 as C
from esm.utils.misc import merge_ranges
from esm.utils.types import FunctionAnnotation


@dataclass(frozen=True)
class FunctionTokenDecoderConfig:
    """Configures function token decoder."""

    # Embedding dimension of decoder.
    d_model: int = 1024
    # Number of attention heads of decoder.
    n_heads: int = 8
    # Number of layers of decoder.
    n_layers: int = 3
    # Number of integer values that function tokens may assume.
    function_token_vocab_size: int = 260
    # Number of function tokens at each position.
    function_token_depth: int = 8
    # Number of InterPro labels that can be decoded.
    num_interpro_classes: int = 35115
    # Number of function keywords that can be decoded.
    keyword_vocabulary_size: int = 68103
    # Path to CSV file mapping InterPro label to keywords.
    interpro2keywords_path: str = C.INTERPRO2KEYWORDS
    # Path mapping InterPro to id.
    interpro2id_path: str = C.INTERPRO_2ID


class FunctionTokenDecoder(nn.Module):
    def __init__(
        self, config: FunctionTokenDecoderConfig = FunctionTokenDecoderConfig()
    ):
        """Constructs function token decoder."""
        super().__init__()
        self.config = config

        with open(config.interpro2id_path, "r") as f:
            interpro2id = json.load(f)
            self.interpro_labels: list[str] = sorted(interpro2id, key=interpro2id.get)
            assert all(self.interpro_labels[i] == ipr for ipr, i in interpro2id.items())
            assert config.num_interpro_classes == len(self.interpro_labels)

        self.embedding = nn.Embedding(
            # Function-token id's re-use the same token ids at each position along the
            # depth dimension, despite distinct meanings. The decoder should take this
            # into account so create distinct embeddings for tokens at each position.
            num_embeddings=(
                self.config.function_token_depth * self.config.function_token_vocab_size
            ),
            embedding_dim=config.d_model,
        )
        self.encoder = TransformerStack(
            d_model=config.d_model,
            n_heads=config.n_heads,
            v_heads=None,
            n_layers=config.n_layers,
            n_layers_geom=0,
            scale_residue=False,
            bias=True,
            qk_layernorm=False,
            ffn_type="gelu",
            expansion_ratio=4,
        )
        self.interpro_head = RegressionHead(
            config.d_model,
            self.config.num_interpro_classes,
            hidden_dim=4 * config.d_model,
        )

    def forward(self, token_ids: torch.Tensor) -> dict[str, torch.Tensor]:
        """Forward pass through function token decoder.

        Args:
            token_ids: <int>[batch_size, function_token_depth] batch of function tokens
                ids to decode.
        Returns:
            interpro_logits: binary classification logits tensor of shape
                <float>[batch_size, num_interpro_classes]
        """
        assert token_ids.ndim == 2
        assert token_ids.shape[1] == self.config.function_token_depth

        # Apply depth-position offset to use distinct vocabs. See __init__ for
        # explaination.
        vocab_offsets = self.config.function_token_vocab_size * torch.arange(
            self.config.function_token_depth,
            device=token_ids.device,
        )
        token_ids = token_ids + vocab_offsets[None, :]

        embed = self.embedding(token_ids)
        encoding, _ = self.encoder(embed)
        pooled = torch.mean(encoding, dim=1)

        return self.interpro_head(pooled)

    @property
    def device(self) -> torch.device:
        return next(self.parameters()).device

    def decode(
        self,
        function_token_ids: torch.Tensor,
        tokenizer: InterProQuantizedTokenizer,
        decode_annotations: bool = True,
        annotation_threshold: float = 0.1,
        decode_keywords=True,
        annotation_min_length: int | None = 5,
        annotation_gap_merge_max: int | None = 3,
    ):
        """Decodes function tokens into predicted annotations and keywords.

        Args:
            function_token_ids: <int>[length, depth] function token ids. NOTE:
                without <bos>/<eos> prefix
            tokenizer: function tokenizer.
            annotation_threshold: threshold for emitting a function annotation.
            annotation_min_length: optional minimum length of predicted annotations for
                size filtering.
            annotation_gap_merge_max: optional merge adjacent annotation of the same type
        Returns:
            - "interpro_logits": <float>[length, num_interpro] predicted interpro logits.
            - "interpro_preds": <bool>[length, num_interpro] predicted intepro labels.
            - "function_keywords": list[FunctionAnnotation] predicted function keyword
                ranges.
        """
        assert function_token_ids.ndim == 2
        assert function_token_ids.shape[1] == tokenizer.depth
        assert self.config.function_token_depth == tokenizer.depth

        outputs = {}

        interpro_logits = self(function_token_ids.to(self.device))
        outputs["interpro_logits"] = interpro_logits

        # Only decode in positions that have function tokens.
        where_decode = torch.all(
            (function_token_ids != tokenizer.vocab_to_index["<pad>"])
            & (function_token_ids != tokenizer.vocab_to_index["<none>"])
            & (function_token_ids != tokenizer.vocab_to_index["<unk>"]),
            dim=1,
        )

        # Decode InterPro annotations ranges.
        if decode_annotations or decode_keywords:
            interpro_preds = F.sigmoid(interpro_logits)
            interpro_preds = interpro_preds >= annotation_threshold
            interpro_preds[~where_decode, :] = False
            outputs["interpro_preds"] = interpro_preds

            annotations: list[FunctionAnnotation] = []
            preds = interpro_preds.detach().cpu().numpy()
            for position_index, class_index in zip(*preds.nonzero()):
                interpro_id = self.interpro_labels[class_index]
                annotation = FunctionAnnotation(
                    label=interpro_id,
                    start=position_index + 1,  # zero-index -> one-index
                    end=position_index + 1,
                )
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

            outputs["interpro_annotations"] = annotations

        # Decode function keyword ranges.
        if decode_keywords:
            outputs["function_keywords"] = self._interpro_to_keyword_ranges(annotations)

        return outputs

    def _interpro_to_keyword_ranges(
        self,
        annotations: list[FunctionAnnotation],
    ) -> list[FunctionAnnotation]:
        """Converts InterPro annotations into keyword annotations.

        Args:
            annotations: InterPro annotations.
        Returns:
            keyword annotations.
        """
        keyword_annotations = []
        for annotation in annotations:
            interpro_id = annotation.label
            assert interpro_id in self.interpro2keywords
            keywords = self.interpro2keywords[interpro_id]
            for keyword in keywords:
                keyword_annotations.append(
                    FunctionAnnotation(
                        label=keyword,
                        start=annotation.start,
                        end=annotation.end,
                    )
                )

        return _merge_annotations(keyword_annotations)

    @cached_property
    def interpro2keywords(self) -> dict[str, list[str]]:
        """Loads mapping of InterPro label to function keywords."""
        df = pd.read_csv(self.config.interpro2keywords_path)
        assert "interpro_id" in df.columns and "keywords" in df.columns
        df["keywords"] = df.keywords.str.split(",")
        return dict(zip(df.interpro_id, df.keywords))


def _merge_annotations(
    annotations: list[FunctionAnnotation],
    merge_gap_max: int | None = None,
) -> list[FunctionAnnotation]:
    """Merges annotations into non-overlapping segments.

    Args:
        annotations: annotations to merge.
        merge_gap_max: optionally merge neighboring ranges that are separated by a gap
          no larger than this size.
    Returns:
        non-overlapping annotations with gaps merged.
    """
    grouped: dict[str, list[range]] = defaultdict(list)
    for a in annotations:
        # Convert one-indexed exclusive-exclusive, to range()
        grouped[a.label].append(range(a.start - 1, a.end - 1 + 1))

    merged = []
    for label, ranges in grouped.items():
        merged_ranges = merge_ranges(ranges, merge_gap_max=merge_gap_max)
        for range_ in merged_ranges:
            annotation = FunctionAnnotation(
                label=label,
                start=range_.start + 1,
                end=range_.stop + 1 - 1,
            )
            merged.append(annotation)
    return merged
