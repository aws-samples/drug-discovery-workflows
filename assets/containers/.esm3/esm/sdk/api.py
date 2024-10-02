from __future__ import annotations

from abc import ABC
from typing import Sequence

import attr
import torch
from attr import define

from esm.tokenization import (
    get_model_tokenizers,
)
from esm.utils import encoding
from esm.utils.constants.models import ESM3_OPEN_SMALL
from esm.utils.structure.protein_chain import ProteinChain
from esm.utils.types import (
    FunctionAnnotation,
    PathLike,
    PathOrBuffer,
)


## Basic Types
@define
class ESMProtein:
    sequence: str | None = None
    secondary_structure: str | None = None
    sasa: list[float | str | None] | None = None
    function_annotations: list[FunctionAnnotation] | None = None
    coordinates: torch.Tensor | None = None
    confidence: torch.Tensor | None = None

    def __len__(self):
        if self.sequence is not None:
            return len(self.sequence)
        elif self.secondary_structure is not None:
            return len(self.secondary_structure)
        elif self.sasa is not None:
            return len(self.sasa)
        elif self.coordinates is not None:
            return self.coordinates.size(0)
        else:
            raise ValueError("No track to determine length from.")

    @classmethod
    def from_pdb(
        cls,
        path: PathOrBuffer,
        chain_id: str = "detect",
        id: str | None = None,
        is_predicted: bool = False,
    ) -> ESMProtein:
        protein_chain = ProteinChain.from_pdb(
            path=path, chain_id=chain_id, id=id, is_predicted=is_predicted
        )
        return cls.from_protein_chain(protein_chain)

    @classmethod
    def from_protein_chain(cls, protein_chain: ProteinChain) -> ESMProtein:
        # TODO: Verify that all fields are consistent and conversions are done appropiately

        return ESMProtein(
            sequence=protein_chain.sequence,
            secondary_structure=None,  # TODO: Fix dssp dependency
            sasa=protein_chain.sasa().tolist(),
            function_annotations=None,
            coordinates=torch.tensor(protein_chain.atom37_positions),
            confidence=torch.tensor(protein_chain.confidence),
        )

    def to_pdb(self, pdb_path: PathLike) -> None:
        protein_chain = self.to_protein_chain()
        protein_chain.to_pdb(pdb_path)

    def to_protein_chain(self) -> ProteinChain:
        if self.coordinates is None:
            raise ValueError("Coordinates are required to convert to a ProteinChain.")
        protein_chain = ProteinChain.from_atom37(
            atom37_positions=self.coordinates.to("cpu").numpy(),
            id=None,
            sequence=self.sequence,
            chain_id=None,
            entity_id=None,
            residue_index=None,
            insertion_code=None,
            confidence=self.confidence,
        )
        return protein_chain


@define
class ESMProteinTensor:
    sequence: torch.Tensor | None = None
    structure: torch.Tensor | None = None
    secondary_structure: torch.Tensor | None = None
    sasa: torch.Tensor | None = None
    function: torch.Tensor | None = None
    residue_annotations: torch.Tensor | None = None
    coordinates: torch.Tensor | None = None
    confidence: torch.Tensor | None = None

    def __len__(self) -> int:
        if self.sequence is not None:
            return self.sequence.size(0)
        elif self.structure is not None:
            return self.structure.size(0)
        elif self.secondary_structure is not None:
            return self.secondary_structure.size(0)
        elif self.sasa is not None:
            return self.sasa.size(0)
        elif self.coordinates is not None:
            return self.coordinates.size(0)
        else:
            raise ValueError("No track to determine length from.")

    @property
    def device(self) -> str | torch.device:
        device_ = None

        tracks = [f.name for f in attr.fields(ESMProteinTensor)]

        for track in tracks:
            current_track: torch.Tensor | None = getattr(self, track)
            if current_track is not None:
                if device_ is not None and device_ != current_track.device:
                    raise ValueError(f"Inconsistent devices for track {track}.")
                device_ = getattr(self, track).device

        if device_ is None:
            raise ValueError("No track to determine device from.")

        return device_

    @classmethod
    def empty(cls, length: int, model_name: str = ESM3_OPEN_SMALL) -> ESMProteinTensor:
        tokenizers = get_model_tokenizers(model_name)

        return ESMProteinTensor(
            sequence=encoding.get_default_sequence_tokens(length, tokenizers.sequence),
            structure=encoding.get_default_structure_tokens(
                length, tokenizers.structure
            ),
            secondary_structure=encoding.get_default_secondary_structure_tokens(
                length, tokenizers.secondary_structure
            ),
            sasa=encoding.get_default_sasa_tokens(length, tokenizers.sasa),
            function=encoding.get_default_function_tokens(length, tokenizers.function),
            residue_annotations=encoding.get_default_residue_annotation_tokens(
                length, tokenizers.residue_annotations
            ),
        )


## High Level Endpoint Types
@define
class GenerationConfig:
    model: str = ""
    track: str = ""
    invalid_ids: Sequence[int] = []
    schedule: str = "cosine"
    num_steps: int = 8
    temperature: float = 1.0
    top_p: float = 1.0


## Low Level Endpoint Types
@define
class SamplingTrackConfig:
    temperature: float = 1.0
    top_p: float = 1.0
    only_sample_masked_tokens: bool = True
    invalid_ids: Sequence[int] = []
    topk_logprobs: int = 0


@define
class SamplingConfig:
    sequence: SamplingTrackConfig | None = None
    structure: SamplingTrackConfig | None = None
    secondary_structure: SamplingTrackConfig | None = None
    sasa: SamplingTrackConfig | None = None
    function: SamplingTrackConfig | None = None


@define
class ReturnLogitsConfig:
    sequence: bool = False
    structure: bool = False
    secondary_structure: bool = False
    sasa: bool = False
    function: bool = False
    residue_annotations: bool = False


@define
class ForwardTrackData:
    sequence: torch.Tensor | None = None
    structure: torch.Tensor | None = None
    secondary_structure: torch.Tensor | None = None
    sasa: torch.Tensor | None = None
    function: torch.Tensor | None = None


@define
class ForwardOutput:
    logits: ForwardTrackData | None = None
    embeddings: torch.Tensor | None = None

    # Residue annotations is multi-hot, so deserves special treatment
    # It's not a categorical distribution, but instead a bernoulli, so
    # softmax across the last dimension is _wrong_
    residue_annotation_logits: torch.Tensor | None = None


@define
class ForwardAndSampleOutput(ForwardOutput):
    protein_tensor: ESMProteinTensor = ESMProteinTensor()

    entropy: ForwardTrackData | None = None
    # Probability of sampled token
    prob: ForwardTrackData | None = None
    logprob: ForwardTrackData | None = None
    # Top probability at this position
    top_prob: ForwardTrackData | None = None
    topk_logprob: ForwardTrackData | None = None
    # Which tokens correspond to top probability
    topk_tokens: ForwardTrackData | None = None


class ESM3InferenceClientV1(ABC):
    def generate(self, input: ESMProtein, config: GenerationConfig) -> ESMProtein:
        ...
        # This is the easiest way to run ESM3. GenerateInput specifies input
        # in raw format, and the output is in raw format as well.
        # It is a local function wrapping calls for encode -> iterative_sampling -> decode.

    def iterative_sampling(
        self, input: ESMProteinTensor, config: GenerationConfig
    ) -> ESMProteinTensor:
        ...
        # /api/v1/iterative_sampling
        # The most flexible way for power users to run ESM3. This allows for arbitrary
        # conditioning and masking strategies. IterativeSamplingInput specifies input
        # in tokenized format, and the output is in tokenized format as well.

    def encode(
        self, input: ESMProtein, override_structure_tokens_with_coords: bool = True
    ) -> ESMProteinTensor:
        ...
        # Encode allows for encoding RawRepresentation into TokenizedRepresentation.
        # This runs the structure_token_encoder, as well as dealing with PDB => atom37 conversion
        #
        # override_structure_tokens_with_coords:
        # If both structure tokens and coordinates are present, structure tokens are used
        # for decoding. By default it is assumed that the predicted structure tokens
        # are preferred over the input coordinates.

    def decode(
        self,
        input: ESMProteinTensor,
        override_structure_tokens_with_coords: bool = False,
    ) -> ESMProtein:
        ...
        # Decode is the inverse of encode, and runs a structure_token_decoder to output coordinates
        #
        # override_structure_tokens_with_coords:
        # If both structure tokens and coordinates are present, structure tokens are used
        # for decoding. By default it is assumed that the predicted structure tokens
        # are preferred over the input coordinates.

    def _forward(
        self,
        input: ESMProteinTensor,
        return_logits: ReturnLogitsConfig = ReturnLogitsConfig(),
        return_embeddings: bool = False,
    ) -> ForwardOutput:
        ...
        # Our API generally discourages using raw forwards as inputs
        # This is because sending logits can be prohibitively expensive
        # Please use forward_and_sample instead

    def forward_and_sample(
        self,
        input: ESMProteinTensor,
        sampling_configuration: SamplingConfig,  # TODO(zeming): return embeddings
    ) -> ForwardAndSampleOutput:
        ...
        # forward_and_sample runs a single model forward, sampling tokens according to `SamplingConfiguration`.
        # This is the way for power users to run ESM3. We hope design this in a way to enable high throughput
        # inference, as well as arbitrary chain-of-though invocations of ESM3.
