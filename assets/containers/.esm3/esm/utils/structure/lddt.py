import torch
from einops import rearrange

from esm.utils import residue_constants as RC


def compute_lddt(
    all_atom_pred_pos: torch.Tensor,
    all_atom_positions: torch.Tensor,
    all_atom_mask: torch.Tensor,
    cutoff: float = 15.0,
    eps: float = 1e-10,
    per_residue: bool = True,
    sequence_id: torch.Tensor | None = None,
) -> torch.Tensor:
    """
    Computes LDDT for a protein. Tensor sizes below include some optional dimensions. Specifically:
        Nstates:
            all_atom_pred_pos can contain multiple states in the first dimension which corresponds to outputs from different layers of a model (e.g. each IPA block). The return size will be [Nstates x Batch size] if this is included.
        Natoms:
            LDDT can be computed for all atoms or some atoms. The second to last dimension should contain the *FLATTENED* representation of L x Natoms. If you want to calculate for atom37, e.g., this will be of size (L * 37). If you are only calculating CA LDDT, it will be of size L.

    Args:
        all_atom_pred_pos (Tensor[float], [(Nstates x) B x (L * Natoms x) 3]): Tensor of predicted positions
        all_atom_positions (Tensor[float], [B x (L * Natoms x) 3]): Tensor of true positions
        all_atom_mask (Tensor[float], [B x (L * Natoms)]): Tensor of masks, indicating whether an atom exists.
        cutoff (float): Max distance to score lddt over.
        per_residue (bool): Whether to return per-residue or full-protein lddt.
        sequence_id (Tensor, optional): Sequence id tensor for binpacking. NOTE: only supported for lddt_ca calculations, not when Natoms is passed!

    Returns:
        LDDT Tensor:
            if per_residue:
                Tensor[float], [(Nstates x) B x (L * Natoms)]
            else:
                Tensor[float], [(Nstates x) B]
    """
    n = all_atom_mask.shape[-2]
    dmat_true = torch.sqrt(
        eps
        + torch.sum(
            (all_atom_positions[..., None, :] - all_atom_positions[..., None, :, :])
            ** 2,
            dim=-1,
        )
    )

    dmat_pred = torch.sqrt(
        eps
        + torch.sum(
            (all_atom_pred_pos[..., None, :] - all_atom_pred_pos[..., None, :, :]) ** 2,
            dim=-1,
        )
    )
    dists_to_score = (
        (dmat_true < cutoff)
        * all_atom_mask
        * rearrange(all_atom_mask, "... a b -> ... b a")
        * (1.0 - torch.eye(n, device=all_atom_mask.device))
    )

    if sequence_id is not None:
        # TODO(roshan): This will work for lddt_ca, but not for regular lddt
        # Problem is that regular lddt has natoms * nres scores, so would need to repeat this mask by natoms
        # Leaving for now because it won't fail silently so should be ook.
        seqid_mask = sequence_id[..., None] == sequence_id[..., None, :]
        dists_to_score = dists_to_score * seqid_mask.type_as(dists_to_score)

    dist_l1 = torch.abs(dmat_true - dmat_pred)

    score = (
        (dist_l1 < 0.5).type(dist_l1.dtype)
        + (dist_l1 < 1.0).type(dist_l1.dtype)
        + (dist_l1 < 2.0).type(dist_l1.dtype)
        + (dist_l1 < 4.0).type(dist_l1.dtype)
    )
    score = score * 0.25

    dims = (-1,) if per_residue else (-2, -1)
    norm = 1.0 / (eps + torch.sum(dists_to_score, dim=dims))
    score = norm * (eps + torch.sum(dists_to_score * score, dim=dims))

    return score


def compute_lddt_ca(
    all_atom_pred_pos: torch.Tensor,
    all_atom_positions: torch.Tensor,
    all_atom_mask: torch.Tensor,
    cutoff: float = 15.0,
    eps: float = 1e-10,
    per_residue: bool = True,
    sequence_id: torch.Tensor | None = None,
) -> torch.Tensor:
    ca_pos = RC.atom_order["CA"]
    if all_atom_pred_pos.dim() != 3:
        all_atom_pred_pos = all_atom_pred_pos[..., ca_pos, :]
    all_atom_positions = all_atom_positions[..., ca_pos, :]
    all_atom_mask = all_atom_mask[..., ca_pos : (ca_pos + 1)]  # keep dim

    return compute_lddt(
        all_atom_pred_pos,
        all_atom_positions,
        all_atom_mask,
        cutoff=cutoff,
        eps=eps,
        per_residue=per_residue,
        sequence_id=sequence_id,
    )
