from __future__ import annotations
from esm.models.esm3 import ESM3, ESMOutput
from esm.utils.constants import esm3 as C
from esm.utils.constants.models import ESM3_OPEN_SMALL

from esm.utils.structure.affine3d import build_affine3d_from_coordinates
import torch
import torch_neuronx
import torch_xla.core.xla_model as xm


class ESM3Neuron(ESM3):
    """
    Wrapped version of ESM3 class for AWS Neuron compilation.
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    @classmethod
    def from_pretrained(
        cls,
        model_name: str = ESM3_OPEN_SMALL,
        device: torch.device | str = "cpu",
    ) -> ESM3Neuron:
        model = super().from_pretrained(model_name, device)
        model.__class__ = cls
        return model

    def forward(
        self,
        sequence_tokens: torch.Tensor | None = None,
        structure_tokens: torch.Tensor | None = None,
        ss8_tokens: torch.Tensor | None = None,
        sasa_tokens: torch.Tensor | None = None,
        function_tokens: torch.Tensor | None = None,
        residue_annotation_tokens: torch.Tensor | None = None,
        average_plddt: torch.Tensor | None = None,
        per_res_plddt: torch.Tensor | None = None,
        structure_coords: torch.Tensor | None = None,
        chain_id: torch.Tensor | None = None,
        sequence_id: torch.Tensor | None = None,
    ) -> tuple:
        """
        Performs forward pass through the ESM3 model. Check utils to see how to tokenize inputs from raw data.

        Args:
            sequence_tokens (torch.Tensor, optional): The amino acid tokens.
            structure_tokens (torch.Tensor, optional): The structure tokens.
            ss8_tokens (torch.Tensor, optional): The secondary structure tokens.
            sasa_tokens (torch.Tensor, optional): The solvent accessible surface area tokens.
            function_tokens (torch.Tensor, optional): The function tokens.
            residue_annotation_tokens (torch.Tensor, optional): The residue annotation tokens.
            average_plddt (torch.Tensor, optional): The average plddt across the entire sequence.
            per_res_plddt (torch.Tensor, optional): The per residue plddt, if you want to specify exact plddts, use this,
                otherwise, use average_plddt.
            structure_coords (torch.Tensor, optional): The structure coordinates, in the form of (B, L, 3, 3).
            chain_id (torch.Tensor, optional): The chain ID
            sequence_id (torch.Tensor, optional): The sequence ID.

        Returns:
            namedtuple: The output of the ESM3 model.

        Raises:
            ValueError: If at least one of the inputs is None.

        """
        # Reasonable defaults:
        print("setting defaults")
        try:
            L, device = next(
                (x.shape[1], x.device)
                for x in [
                    sequence_tokens,
                    structure_tokens,
                    ss8_tokens,
                    sasa_tokens,
                    structure_coords,
                    function_tokens,
                    residue_annotation_tokens,
                ]
                if x is not None
            )
        except StopIteration:
            raise ValueError("At least one of the inputs must be non-None")

        defaults = lambda x, tok: (
            torch.full((1, L), tok, dtype=torch.long, device=device) if x is None else x
        )
        sequence_tokens = defaults(sequence_tokens, C.SEQUENCE_MASK_TOKEN)
        ss8_tokens = defaults(ss8_tokens, C.SS8_UNK_TOKEN)
        sasa_tokens = defaults(sasa_tokens, C.SASA_UNK_TOKEN)
        average_plddt = defaults(average_plddt, 1).float()
        per_res_plddt = defaults(per_res_plddt, 0).float()
        chain_id = defaults(chain_id, 0)
        sequence_id = defaults(sequence_id, 0)

        if residue_annotation_tokens is None:
            residue_annotation_tokens = torch.full(
                (1, L, 16), C.RESIDUE_PAD_TOKEN, dtype=torch.long, device=device
            )

        if function_tokens is None:
            function_tokens = torch.full(
                (1, L, 8), C.INTERPRO_PAD_TOKEN, dtype=torch.long, device=device
            )

        if structure_coords is None:
            structure_coords = torch.full(
                (1, L, 3, 3), float("nan"), dtype=torch.float, device=device
            )

        structure_coords = structure_coords[
            :, :, :3, :
        ]  # In case we pass in an atom14 or atom37 repr
        affine, affine_mask = build_affine3d_from_coordinates(structure_coords)

        if structure_tokens is None:
            _, structure_tokens = self.get_structure_token_encoder().encode(
                structure_coords
            )
        assert structure_tokens is not None
        structure_tokens = (
            structure_tokens.masked_fill(
                (structure_tokens == -1) | ~affine_mask, C.STRUCTURE_MASK_TOKEN
            )
            .masked_fill(sequence_tokens == C.SEQUENCE_BOS_TOKEN, C.STRUCTURE_BOS_TOKEN)
            .masked_fill(sequence_tokens == C.SEQUENCE_PAD_TOKEN, C.STRUCTURE_PAD_TOKEN)
            .masked_fill(sequence_tokens == C.SEQUENCE_EOS_TOKEN, C.STRUCTURE_EOS_TOKEN)
            .masked_fill(
                sequence_tokens == C.SEQUENCE_CHAINBREAK_TOKEN,
                C.STRUCTURE_CHAINBREAK_TOKEN,
            )
        )
        print("Running encoder blocks")
        x = self.encoder(
            sequence_tokens,
            structure_tokens,
            average_plddt,
            per_res_plddt,
            ss8_tokens,
            sasa_tokens,
            function_tokens,
            residue_annotation_tokens,
        )
        print("Running transformer blocks")
        x, embedding = self.transformer(x, sequence_id, affine, affine_mask, chain_id)

        print("Running decoder blocks")
        output = self.output_heads(x, embedding)

        print("Formatting outputs")


        results = (
            output.sequence_logits,
            output.structure_logits,
            output.secondary_structure_logits,
            output.sasa_logits,
            output.function_logits,
            output.residue_logits,
            output.embeddings,
        )
        return results
