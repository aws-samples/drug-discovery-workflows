# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import os
import math
import time
import json
import contextlib

import torch as th
from torch import nn
import safetensors

from torch.optim import Optimizer
from torch.optim.lr_scheduler import LambdaLR
from transformers.trainer_pt_utils import get_parameter_names
from transformers import AutoConfig, AdamW, EsmModel, EsmForMaskedLM, BertForMaskedLM
from torch.optim import Adam
import deepspeed

from tape.models.modeling_utils import accuracy
from tape import ProteinBertModel, ProteinBertForMaskedLM



def initialize_lm(pretrained_ckpt_path: str, with_lm_head: bool=False):
    hf_config = AutoConfig.from_pretrained(pretrained_ckpt_path)
    lm_hidden_size = hf_config.hidden_size
    if hf_config.model_type == "bert":
        # tape model
        LMClass = ProteinBertForMaskedLM if with_lm_head else ProteinBertModel
    else:
        LMClass = EsmForMaskedLM if with_lm_head else EsmModel

    # Do not load weights here, it will be handled by `model_init_fn`
    lm = LMClass(config=hf_config)
    return lm, lm_hidden_size

class ProteinLM(nn.Module):
    """The unified interface for protein language models.
    """
    def __init__(self, pretrained_ckpt_path: str, with_lm_head: bool=False):
        super().__init__()
        self.pretrained_ckpt_path = pretrained_ckpt_path
        self.with_lm_head = with_lm_head
        lm, lm_hidden_size = initialize_lm(pretrained_ckpt_path, with_lm_head)
        self.lm = lm
        self.lm_hidden_size = lm_hidden_size
        self.vocab_size = lm.config.vocab_size
        
    def _get_last_hidden_state(self, input_ids: th.Tensor, attention_mask: th.Tensor):
        """
        Get last layer hidden state with shape [B, L, hidden_size]
        """
        if isinstance(self.lm, ProteinBertModel):
            outputs = self.lm(input_ids, input_mask=attention_mask)
            feature = outputs[0]
        else:
            outputs = self.lm(input_ids, attention_mask=attention_mask, output_hidden_states=True)
            if hasattr(outputs, "last_hidden_state"):
                feature = outputs.last_hidden_state
            else:
                feature = outputs.hidden_states[-1]
        # feature should be: [B, L, hidden_size]
        assert feature.shape == th.Size((input_ids.shape[0], input_ids.shape[1], self.lm_hidden_size))
        return feature

    def _get_sequence_representation(self, input_ids: th.Tensor, attention_mask: th.Tensor):
        """
        Get sequence-level representation [B, hidden_size] by avg pooling
        """
        feature = self._get_last_hidden_state(input_ids, attention_mask)
        # averge pool for the last hidden state to get seq-level rep
        num_of_tokens = attention_mask.sum(dim=1, keepdim=True)  # (B, 1)
        pooled_hidden_state = (feature * attention_mask.unsqueeze(dim=-1)).sum(
            dim=1
        ) / num_of_tokens  # (B, hidden_size)
        return pooled_hidden_state

    def get_sequence_representation(self, batch: dict):
        """Support multi-chain inputs.
        """
        input_ids = batch.get("input_ids")
        if input_ids is not None:
            # single chain inputs
            attention_mask = self._get_attention_mask(batch)
            return self._get_sequence_representation(input_ids, attention_mask)
        else:
            # assumes H_chain and L_chain
            input_ids_h = batch["H_chain"]["input_ids"]
            attention_mask_h = batch["H_chain"]["attention_mask"]
            z_h = self._get_sequence_representation(input_ids_h, attention_mask_h)
            input_ids_l = batch["L_chain"]["input_ids"]
            attention_mask_l = batch["L_chain"]["attention_mask"]
            z_l = self._get_sequence_representation(input_ids_l, attention_mask_l)
            return z_h + z_l # [B, hidden_size]

    def _forward(self, input_ids: th.Tensor, attention_mask: th.Tensor, labels=None):
        """input_ids [B, L] to logits [B, L, vocab_size]
        """
        assert self.with_lm_head, "LMhead not available"
        if isinstance(self.lm, ProteinBertForMaskedLM):
            outputs = self.lm(input_ids, input_mask=attention_mask, targets=labels)
            logits = outputs[1]
            mlm_loss = outputs[0] # mlm loss
        else:
            outputs = self.lm(input_ids, attention_mask=attention_mask, labels=labels)
            logits = outputs.logits  # [B, L, vocab_size]
            mlm_loss = outputs.loss
        return mlm_loss, logits

    def _get_tensor(self, batch: dict, names: list) -> th.Tensor:
        tensor = batch.get(names[0])
        if tensor is None:
            tensor = batch.get(names[1])
        return tensor

    def _get_attention_mask(self, batch: dict) -> th.Tensor:
        """Depending on the datasets, it can be named input_mask or attention_mask"""
        return self._get_tensor(batch, ["input_mask", "attention_mask"])

    def _get_labels(self, batch: dict) -> th.Tensor:
        """Depending on the datasets, it can be named input_mask or attention_mask"""
        return self._get_tensor(batch, ["targets", "labels"])


class SequenceRegressionHead(nn.Module):
    """
    Simple regression head similar to SequenceClassificationHead
    """
    def __init__(self, in_dim: int, hid_dim: int, out_dim: int, dropout: float = 0.0):
        super().__init__()
        self.predict = nn.Sequential(
            nn.Linear(in_dim, hid_dim),
            nn.ReLU(),
            nn.Dropout(dropout, inplace=False),
            nn.Linear(hid_dim, out_dim),
        )

    def forward(self, pooled_output, targets=None):
        logits = self.predict(pooled_output)
        outputs = (logits,)

        if targets is not None:
            loss_fct = nn.MSELoss()
            regression_loss = loss_fct(logits, targets)
            metrics = {}
            loss_and_metrics = (regression_loss, metrics)
            outputs = (loss_and_metrics,) + outputs

        return outputs  # (loss), logits

class SequenceRegressionModel(nn.Module):
    def __init__(self, pretrained_ckpt_path, num_labels, dropout):
        super().__init__()
        self.plm = ProteinLM(pretrained_ckpt_path)
        self.predict = SequenceRegressionHead(
            self.plm.lm_hidden_size, 512, num_labels, dropout
        )

    def forward(self, batch):
        targets = self.plm._get_labels(batch)
        pooled_hidden_state = self.plm.get_sequence_representation(batch)
        return self.predict(
            pooled_hidden_state, targets
        )  # (MSEloss, metric_dict), logits


MODEL_CLASS_MAPPING = {
    "SequenceRegressionModel": SequenceRegressionModel
}

def get_dtype(precision):
    """
    Given PTL precision, convert to torch dtype
    """
    if precision == 16:
        return th.float16
    elif precision == "bf16":
        return th.bfloat16
    elif precision == 32:
        return th.float32
    else:
        raise NotImplementedError(f"precision {precision} not implemented")


def load_state_dict_from_dir(path):
    """Find and load model weight file(s)"""
    files = set(os.listdir(path))
    print(f"Loading model weights from {path}")
    if "model.safetensors" in files:
        state_dict_file = os.path.join(path, "model.safetensors")
        state_dict = safetensors.torch.load_file(state_dict_file, device="cpu")
    elif "pytorch_model.bin.index.json" in files:
        # multiple pytorch_model-00001-of-00002.bin files
        meta = json.load(open(os.path.join(path, "pytorch_model.bin.index.json"), "r"))
        state_dict = {}
        for state_dict_file in set(meta["weight_map"].values()):
            # print("Loading ", state_dict_file)
            state_dict.update(
                th.load(os.path.join(path, state_dict_file), map_location="cpu")
            )
    elif "pytorch_model.bin" in files:
        state_dict = th.load(
            os.path.join(path, "pytorch_model.bin"), map_location="cpu"
        )
    elif "state_dict.pt" in files:
        state_dict = th.load(os.path.join(path, "state_dict.pt"), map_location="cpu")
    elif "lightning_model.pt" in files:
        state_dict = th.load(os.path.join(path, "lightning_model.pt"), map_location="cpu")["state_dict"]
    return state_dict


def model_init_fn(trainer, model_cfg):
    """deepspeed-compatible model initialization
    Do not depend on this for loading model state_dict
    Use `ckpt_path` for lightning trainer instead
    """
    unwrapped_state_dict = None
    if trainer.is_global_zero and not model_cfg.no_pretrain:
        # find and load model weight file
        state_dict = load_state_dict_from_dir(model_cfg.pretrained_ckpt_path)
        if "state_dict" in state_dict:
            state_dict = state_dict["state_dict"]
        if "module" in state_dict:
            state_dict = state_dict["module"]
        unwrapped_state_dict = {}
        for key, value in state_dict.items():
            if key.startswith("_forward_module"):  # deepspeed zero_to_fp32.py
                # strip "_forward_module.model"
                key = ".".join(key.split(".")[2:])
            if key.startswith("model"):
                new_key = ".".join(key.split(".")[1:])
            elif key.startswith("esm"):
                # strip model-specific prefixes
                new_key = ".".join(key.split(".")[1:])
            else:
                # execution path if loading pytorch_model.bin
                # key does not need to change
                new_key = key

            unwrapped_state_dict[new_key] = value


    def check_state_dict_keys_match(model: nn.Module):
        """
        Check if the unwrapped_state_dict match all the keys expected from a model.
        Also handles an edge case for BiMamba, where "backbone.layers.{}.mixer.mamba_rev.in_proj.weight" is tied with "mamba_fwd". In packaged deepspeed checkpoint, tied weights are not duplicated.
        """
        nonlocal unwrapped_state_dict
        all_keys_match = set(unwrapped_state_dict) == set(model.state_dict().keys())
        return all_keys_match
    
    def load(module: th.nn.Module, prefix=""):
        nonlocal unwrapped_state_dict
        missing_keys = []
        unexpected_keys = []
        error_msgs = []
        # copy state_dict so _load_from_state_dict can modify it
        metadata = getattr(unwrapped_state_dict, "_metadata", None)
        state_dict = None
        if trainer.is_global_zero:
            state_dict = unwrapped_state_dict.copy()

            if metadata is not None:
                state_dict._metadata = metadata

        local_metadata = {} if metadata is None else metadata.get(prefix[:-1], {})

        # because zero3 puts placeholders in model params, this context
        # manager gathers (unpartitions) the params of the current layer, then loads from
        # the state dict and finally re-partitions them
        with deepspeed.zero.GatheredParameters(
            list(module.parameters(recurse=False)), modifier_rank=0
        ):
            if trainer.is_global_zero:
                module._load_from_state_dict(
                    state_dict=state_dict,
                    prefix=prefix,
                    local_metadata=local_metadata,
                    strict=True,
                    missing_keys=missing_keys,
                    unexpected_keys=unexpected_keys,
                    error_msgs=error_msgs,
                )

        for name, child in module._modules.items():
            if child is not None:
                load(child, prefix + name + ".")

    init_dtype = get_dtype(trainer.precision)
    is_zero3 = False
    context = contextlib.nullcontext()

    with context:
        model = MODEL_CLASS_MAPPING[model_cfg.class_name](
            model_cfg.pretrained_ckpt_path,
            model_cfg.num_labels,
            model_cfg.dropout,
        )
    if not model_cfg.no_pretrain:
        if trainer.is_global_zero:
            all_keys_match = check_state_dict_keys_match(model)
            if all_keys_match:
                # load all weights (pLM + head)
                load(model, prefix="")
            else:
                # load the weights for pLM only
                load(model.plm.lm, prefix="")
            if isinstance(model.plm.lm, EsmForMaskedLM):
                load(model.plm.lm.esm, prefix="") # is this needed?
                if not is_zero3:
                    assert th.all(unwrapped_state_dict['lm_head.dense.weight'] == model.plm.lm.lm_head.dense.weight), "Loading of pretrained LMHead failed!"

            if not is_zero3:
                # For zero2, make sure the weights are actually loaded into model
                embedding_weight_key = None
                inner_plm = model.plm.lm
                if isinstance(inner_plm, EsmModel):
                    embedding_weights = inner_plm.embeddings.word_embeddings.weight
                    embedding_weight_key = "embeddings.word_embeddings.weight"
                elif isinstance(inner_plm, EsmForMaskedLM):
                    embedding_weights = inner_plm.esm.embeddings.word_embeddings.weight
                    embedding_weight_key = "embeddings.word_embeddings.weight"
                elif isinstance(inner_plm, BertForMaskedLM):
                    embedding_weights = inner_plm.bert.embeddings.word_embeddings.weight
                    embedding_weight_key = "bert.embeddings.word_embeddings.weight"
                if embedding_weight_key:
                    if all_keys_match:
                        embedding_weight_key = f"plm.lm.{embedding_weight_key}"
                    assert embedding_weights[0, 0] == unwrapped_state_dict[embedding_weight_key][0, 0], "Loading of pretrained weights failed!"

    return model