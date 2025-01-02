"""
Adapted from https://gitlab.aws.dev/hodgkin-spt/sm_training_base/-/blob/hodgkin-dev/src/protein_lm_tasks/
`modelmodule.py` and `simple_load.py`
Functions to load protein language models and associated fine-tuned models from Applied Sciences team.
"""

import os
import math
import time
import json
# import hydra
import contextlib

# import pytorch_lightning as pl
import torch as th
from torch import nn
import safetensors

from torch.optim import Optimizer
from torch.optim.lr_scheduler import LambdaLR
from transformers.trainer_pt_utils import get_parameter_names
from transformers import AutoConfig, AdamW, EsmModel, EsmForMaskedLM, BertForMaskedLM
from torch.optim import Adam
import deepspeed
# import torchmetrics

from tape.models.modeling_utils import accuracy
from tape import ProteinBertModel, ProteinBertForMaskedLM

# from bimamba_model import BiMambaConfigHF, BiMambaForMaskedLM
# from ProtMamba_ssm.modules import MambaLMHeadModelwithPosids

def get_optimizer(optim_groups, optimizer_cfg):
    optim_cls = AdamW if optimizer_cfg.adam_w_mode else Adam

    args = [optim_groups]
    kwargs = {
        "lr": optimizer_cfg.lr,
        "eps": optimizer_cfg.eps,
        "betas": (optimizer_cfg.betas[0], optimizer_cfg.betas[1]),
    }

    optimizer = optim_cls(*args, **kwargs)
    return optimizer


def get_cosine_schedule_with_warmup(
    optimizer: Optimizer,
    num_warmup_steps: int,
    num_training_steps: int,
    num_cycles: float = 0.5,
    last_epoch: int = -1,
    min_ratio: float = 0.0,
    plateau_ratio: float = 0.0,
):
    """
    Create a schedule with a learning rate that decreases following the values of the cosine function between the
    initial lr set in the optimizer to 0, after a warmup period during which it increases linearly between 0 and the
    initial lr set in the optimizer.

    Args:
        optimizer (:class:`~torch.optim.Optimizer`):
            The optimizer for which to schedule the learning rate.
        num_warmup_steps (:obj:`int`):
            The number of steps for the warmup phase.
        num_training_steps (:obj:`int`):
            The total number of training steps.
        num_cycles (:obj:`float`, `optional`, defaults to 0.5):
            The number of waves in the cosine schedule (the defaults is to just decrease from the max value to 0
            following a half-cosine).
        last_epoch (:obj:`int`, `optional`, defaults to -1):
            The index of the last epoch when resuming training.
        min_ratio (:obj:`float`, `optional`, defaults to 0.0):
            The minimum ratio a learning rate would decay to.
        plateau_ratio (:obj:`float`, `optional`, defaults to 0.0):
            The ratio for plateau phase.

    Return:
        :obj:`torch.optim.lr_scheduler.LambdaLR` with the appropriate schedule.
    """

    def lr_lambda(current_step):
        plateau_steps = int(plateau_ratio * num_training_steps)
        if current_step < num_warmup_steps:
            return float(current_step) / float(max(1, num_warmup_steps))
        elif current_step < num_warmup_steps + plateau_steps:
            return 1.0
        progress = float(current_step - num_warmup_steps - plateau_steps) / float(
            max(1, num_training_steps - num_warmup_steps - plateau_steps)
        )
        return max(
            min_ratio,
            0.5 * (1.0 + math.cos(math.pi * float(num_cycles) * 2.0 * progress)),
        )

    return LambdaLR(optimizer, lr_lambda, last_epoch)


def initialize_lm(pretrained_ckpt_path: str, with_lm_head: bool=False):
    # if "ProtMamba-Long-foundation" in pretrained_ckpt_path:
    #     # ProtMamba model
    #     # pretrained_ckpt_path = "/opt/ml/input/data/fsx_out/cache/ProtMamba-Long-foundation"
    #     lm = MambaLMHeadModelwithPosids.from_pretrained(
    #         pretrained_ckpt_path,
    #         checkpoint_mixer=False)
    #     lm_hidden_size = lm.config.d_model
    # else:
        # if "bimamba" in pretrained_ckpt_path.lower():
        #     assert with_lm_head, "Loading BiMamba model without lm_head is not supported"
        #     hf_config = BiMambaConfigHF.from_pretrained(pretrained_ckpt_path)
        #     LMClass = BiMambaForMaskedLM
        #     lm_hidden_size = hf_config.d_model
        # else:
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
        # elif isinstance(self.lm, MambaLMHeadModelwithPosids):
        #     position_ids = th.arange(input_ids.shape[1])
        #     position_ids = th.tile(position_ids, [input_ids.shape[0], 1]) # [B, L]
        #     position_ids = position_ids.to(input_ids.device)
        #     feature = self.lm.backbone(
        #         input_ids=input_ids, 
        #         position_ids=position_ids,
        #         inference_params=None,
        #         save_layer=[],
        #         ) # [B, L, hidden_size]
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


class SequenceClassificationHead(nn.Module):
    """
    tape.models.modeling_utils.SequenceClassificationHead without weight_norm
    """

    def __init__(self, in_dim: int, hid_dim: int, out_dim: int, dropout: float = 0.0):
        super().__init__()
        self.classify = nn.Sequential(
            nn.Linear(in_dim, hid_dim),
            nn.ReLU(),
            nn.Dropout(dropout, inplace=False),
            nn.Linear(hid_dim, out_dim),
        )
        if out_dim == 1: # binary classification
            self.loss_fct = nn.BCEWithLogitsLoss()
            # do not compute metrics that are not accumulate-able
            self.metric_funcs = {}
        else: # multiclass
            self.loss_fct = nn.CrossEntropyLoss()
            self.metric_funcs = {"accuracy": accuracy}

    def compute_metrics(self, logits, targets):
        metrics = {}
        targets = targets.long()
        for metric_name, metric_func in self.metric_funcs.items():
            metrics[metric_name] = metric_func(logits, targets)
        return metrics

    def forward(self, pooled_output, targets=None):
        logits = self.classify(pooled_output)
        outputs = (logits,)

        if targets is not None:
            classification_loss = self.loss_fct(logits, targets)
            metrics = self.compute_metrics(logits, targets)
            loss_and_metrics = (classification_loss, metrics)
            outputs = (loss_and_metrics,) + outputs

        return outputs  # (loss), logits

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


class SequenceClassificationModel(nn.Module):
    def __init__(self, pretrained_ckpt_path, num_labels, dropout):
        super().__init__()
        self.plm = ProteinLM(pretrained_ckpt_path)
        self.classify = SequenceClassificationHead(
            self.plm.lm_hidden_size, 512, num_labels, dropout
        )

    def forward(self, batch):
        targets = self.plm._get_labels(batch)
        pooled_hidden_state = self.plm.get_sequence_representation(batch)
        return self.classify(
            pooled_hidden_state, targets
        )  # (x-ent loss, metric_dict), logits

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

class TokenClassificationModel(nn.Module):
    def __init__(self, pretrained_ckpt_path, num_labels, dropout):
        super().__init__()
        self.plm = ProteinLM(pretrained_ckpt_path)
        self.dropout = nn.Dropout(dropout)
        self.classifier = nn.Linear(self.plm.lm_hidden_size, num_labels)
        self.num_labels = num_labels

    def forward(self, batch):
        targets = self.plm._get_labels(batch)        
        input_ids = batch.get("input_ids")
        attention_mask = self.plm._get_attention_mask(batch)
        sequence_output = self.plm._get_last_hidden_state(input_ids, attention_mask)
        sequence_output = self.dropout(sequence_output)
        logits = self.classifier(sequence_output)
        loss = None
        if targets is not None:
            loss_fct = nn.CrossEntropyLoss(ignore_index=-1)
            targets = targets.to(logits.device)
            loss = loss_fct(logits.view(-1, self.num_labels), targets.view(-1))
            metrics = {"accuracy": accuracy(logits, targets, ignore_index=-1)}
            loss = (loss, metrics)
        return loss, logits # (x-ent loss, metric_dict), logits


class MaskedLM(nn.Module):
    def __init__(self, pretrained_ckpt_path, num_labels, dropout):
        super().__init__()
        self.plm = ProteinLM(pretrained_ckpt_path, with_lm_head=True)

    @th.no_grad()
    def calculate_naturalness_score(self, logits, labels):
        # logits: [B, L, |V|]
        # labels: [B, L]
        B, L, V = logits.shape
        mlm_mask = labels != -100
        loss_fct = nn.CrossEntropyLoss(reduction='none')
        # average over number of masked tokens
        # this is perplexity, which is non-deterministic
        pll = loss_fct(
            logits.view(-1, self.plm.vocab_size), 
            labels.view(-1)
            ).view(B, L).sum(axis=1) / mlm_mask.sum(axis=1) # [B] 
        naturalness_scores = th.exp(pll)
        # nan can be introduced when none of the residues in a sequence is masked
        # exclude them from the calculation:
        naturalness_scores = naturalness_scores.nanmean()
        return naturalness_scores
    
    def forward(self, batch):
        input_ids = batch["input_ids"]
        attention_mask = self.plm._get_attention_mask(batch)
        labels = self.plm._get_labels(batch)
        mlm_loss, logits = self.plm._forward(input_ids, attention_mask=attention_mask, labels=labels)
        
        if labels is not None:
            metrics = {"naturalness": self.calculate_naturalness_score(logits, labels)}
            loss = (mlm_loss, metrics)
        return loss, logits # (x-ent loss, metric_dict), logits


MODEL_CLASS_MAPPING = {
    "SequenceClassificationModel": SequenceClassificationModel,
    "SequenceRegressionModel": SequenceRegressionModel,
    "TokenClassificationModel": TokenClassificationModel,
    "MaskedLM": MaskedLM,
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
        # if not all_keys_match:
        #     # check if this is the bimamba edge case
        #     if isinstance(model.plm.lm, BiMambaForMaskedLM) and model.plm.lm.config.bidirectional:
        #         missing_keys = set(model.state_dict().keys()) - set(unwrapped_state_dict)
        #         if all(["mamba_rev" in key for key in missing_keys]):
        #             for missing_key in missing_keys:
        #                 tied_key = missing_key.replace("mamba_rev", "mamba_fwd")
        #                 unwrapped_state_dict[missing_key] = unwrapped_state_dict[tied_key]
        #             all_keys_match = True
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
    
    # if isinstance(trainer.strategy, pl.strategies.DeepSpeedStrategy):
    #     is_zero3 = trainer.strategy.config["zero_optimization"]["stage"] == 3
    #     context = deepspeed.zero.Init(
    #         remote_device=trainer.strategy.remote_device,
    #         pin_memory=True,
    #         config_dict_or_path=trainer.strategy.config,
    #         dtype=init_dtype,
    #         enabled=is_zero3,
    #     )
    # else:
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
                # if isinstance(inner_plm, BiMambaForMaskedLM):
                #     embedding_weights = inner_plm.bimamba.backbone.embedding.weight
                #     embedding_weight_key = "bimamba.backbone.embedding.weight"
                if isinstance(inner_plm, EsmModel):
                    embedding_weights = inner_plm.embeddings.word_embeddings.weight
                    embedding_weight_key = "embeddings.word_embeddings.weight"
                elif isinstance(inner_plm, EsmForMaskedLM):
                    embedding_weights = inner_plm.esm.embeddings.word_embeddings.weight
                    embedding_weight_key = "embeddings.word_embeddings.weight"
                elif isinstance(inner_plm, BertForMaskedLM):
                    embedding_weights = inner_plm.bert.embeddings.word_embeddings.weight
                    embedding_weight_key = "bert.embeddings.word_embeddings.weight"
                # elif isinstance(inner_plm, MambaLMHeadModelwithPosids):
                #     embedding_weights = inner_plm.backbone.embedding.weight
                #     embedding_weight_key = "backbone.embedding.weight"
                if embedding_weight_key:
                    if all_keys_match:
                        embedding_weight_key = f"plm.lm.{embedding_weight_key}"
                    assert embedding_weights[0, 0] == unwrapped_state_dict[embedding_weight_key][0, 0], "Loading of pretrained weights failed!"

    return model