import functools

import einops
import torch
import torch.nn.functional as F
from torch import nn

from esm.layers.rotary import RotaryEmbedding


class MultiHeadAttention(nn.Module):
    def __init__(
        self,
        d_model: int,
        n_heads: int,
        bias: bool = False,
        qk_layernorm: bool = True,
    ):
        super().__init__()

        self.d_model = d_model
        self.n_heads = n_heads

        self.d_head = self.d_model // self.n_heads
        self.layernorm_qkv = nn.Sequential(
            nn.LayerNorm(d_model), nn.Linear(d_model, d_model * 3, bias=bias)
        )
        self.out_proj = nn.Linear(d_model, d_model, bias=bias)

        if qk_layernorm:
            self.q_ln = nn.LayerNorm(d_model, bias=bias)
            self.k_ln = nn.LayerNorm(d_model, bias=bias)
        else:
            self.q_ln = nn.Identity()
            self.k_ln = nn.Identity()

        self.rotary = RotaryEmbedding(d_model // n_heads)

    def _apply_rotary(self, q: torch.Tensor, k: torch.Tensor):
        q = q.unflatten(-1, (self.n_heads, self.d_head))
        k = k.unflatten(-1, (self.n_heads, self.d_head))
        q, k = self.rotary(q, k)
        q = q.flatten(-2, -1)
        k = k.flatten(-2, -1)
        return q, k

    def forward(self, x, seq_id):
        qkv_BLD3 = self.layernorm_qkv(x)
        query_BLD, key_BLD, value_BLD = torch.chunk(qkv_BLD3, 3, dim=-1)
        query_BLD, key_BLD = self.q_ln(query_BLD), self.k_ln(key_BLD)
        query_BLD, key_BLD = self._apply_rotary(query_BLD, key_BLD)

        n_heads = self.n_heads
        reshaper = functools.partial(
            einops.rearrange, pattern="b s (h d) -> b h s d", h=n_heads
        )

        query_BHLD, key_BHLD, value_BHLD = map(
            reshaper, (query_BLD, key_BLD, value_BLD)
        )

        # Where True, enable participation in attention.
        mask_BLL = seq_id.unsqueeze(-1) == seq_id.unsqueeze(-2)
        mask_BHLL = mask_BLL.unsqueeze(1)

        context_BHLD = F.scaled_dot_product_attention(
            query_BHLD, key_BHLD, value_BHLD, mask_BHLL
        )
        context_BLD = einops.rearrange(context_BHLD, "b h s d -> b s (h d)")
        return self.out_proj(context_BLD)
