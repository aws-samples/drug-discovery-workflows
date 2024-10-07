import attr
import torch
from tqdm import tqdm

from esm.sdk.api import (
    ESM3InferenceClientV1,
    ESMProtein,
    ESMProteinTensor,
    GenerationConfig,
    SamplingConfig,
    SamplingTrackConfig,
)
from esm.tokenization import (
    TokenizerCollection,
)
from esm.utils.constants.esm3 import MAX_RESIDUE_ANNOTATIONS
from esm.utils.noise_schedules import NOISE_SCHEDULE_REGISTRY


def iterative_sampling_raw(
    client: ESM3InferenceClientV1,
    input: ESMProtein,
    config: GenerationConfig,
):
    # Keep structure tokens
    input_tokens = client.encode(input, override_structure_tokens_with_coords=False)

    output_tokens = client.iterative_sampling(input_tokens, config)

    raw_protein = client.decode(output_tokens)

    track_to_sample = config.track

    if track_to_sample not in ["function", "residue_annotations"]:
        # Function and residue annotation encoding/decoding is lossy
        # There is no guarantee that decoding encoded tokens will yield the same input
        raw_protein.function_annotations = input.function_annotations

    return raw_protein


def iterative_sampling_tokens(
    client: ESM3InferenceClientV1,
    input_tokens: ESMProteinTensor,
    cfg: GenerationConfig,
    tokenizers: TokenizerCollection,
) -> ESMProteinTensor:
    track_to_sample = cfg.track

    # Get all tracks that require sampling
    all_tracks = [f.name for f in attr.fields(SamplingConfig)]

    sequence_length = len(input_tokens)
    device = input_tokens.device

    # Initialize schedule and masks
    decoding_schedule = NOISE_SCHEDULE_REGISTRY[cfg.schedule]
    sampling_masks: dict[str, torch.Tensor] = {}
    sampled_tokens = attr.evolve(input_tokens)  # Make a copy
    get_tokenizer = lambda s: getattr(tokenizers, s)
    for current_track in all_tracks:
        if current_track != track_to_sample:
            continue
        if getattr(sampled_tokens, current_track) is None:
            if current_track == "function":
                dims = (sequence_length, tokenizers.function.depth)
            elif current_track == "residue_annotations":
                dims = (sequence_length, MAX_RESIDUE_ANNOTATIONS)
            else:
                dims = (sequence_length,)
            masked_tokens = torch.full(
                dims,
                get_tokenizer(current_track).mask_token_id,
                dtype=torch.long,
                device=device,
            )
            if current_track == "sequence":
                masked_tokens[0] = tokenizers.sequence.cls_token_id  # type: ignore
                masked_tokens[-1] = tokenizers.sequence.eos_token_id  # type: ignore
            else:
                masked_tokens[0] = get_tokenizer(current_track).bos_token_id
                masked_tokens[-1] = get_tokenizer(current_track).eos_token_id

            setattr(
                sampled_tokens,
                current_track,
                masked_tokens,
            )

        if current_track == track_to_sample:
            sampling_mask = torch.ones(
                sequence_length,
                dtype=torch.bool,
                device=device,
            )
            sampling_mask[0] = False
            sampling_mask[-1] = False
            sampling_masks[current_track] = sampling_mask

        else:
            sampling_masks[current_track] = torch.zeros(
                sequence_length, dtype=torch.bool, device=device
            )

    # Decode

    def maybe_clone(x: torch.Tensor | None) -> torch.Tensor | None:
        return x.clone() if x is not None else None

    L = sequence_length - 2
    positions_sampled = 0
    for t in tqdm(range(cfg.num_steps)):
        # Single step sampling at all positions
        track_sample_config = SamplingTrackConfig()
        track_sample_config.invalid_ids = cfg.invalid_ids
        track_sample_config.temperature = cfg.temperature
        track_sample_config.top_p = cfg.top_p
        sampling_config = SamplingConfig(**{track_to_sample: track_sample_config})

        sampled_tokens.coordinates = maybe_clone(input_tokens.coordinates)
        sampled_tokens.confidence = maybe_clone(input_tokens.confidence)
        forward_and_sample_output = client.forward_and_sample(
            sampled_tokens, sampling_config
        )
        new_samples = forward_and_sample_output.protein_tensor

        # Calculate number of tokens to sample
        perc_masked = decoding_schedule(torch.tensor((t + 1) / cfg.num_steps))
        num_to_sample = int((1 - perc_masked) * L) - positions_sampled
        positions_sampled += num_to_sample

        # Select tokens based on lowest entropy
        for current_track in all_tracks:
            if current_track != track_to_sample:
                continue
            if current_track in ["function", "residue_annotations"]:
                # TODO: Implement iterative decoding for function and residue_annotations
                # TODO: Fix encode/decode of interpro tokens (not yet supported)
                sampled_tokens.function = maybe_clone(input_tokens.function)
                sampled_tokens.residue_annotations = maybe_clone(
                    input_tokens.residue_annotations
                )
                if current_track in track_to_sample:
                    raise NotImplementedError(
                        f"Iterative decoding for {current_track} is not supported yet."
                    )
                continue

            sampling_mask = sampling_masks[current_track]
            sampling_mask = sampling_mask & (
                getattr(sampled_tokens, current_track)
                == get_tokenizer(current_track).mask_token_id
            )

            track_entropy: torch.Tensor = getattr(
                forward_and_sample_output.entropy, current_track
            )
            track_entropy = track_entropy.masked_fill(
                ~sampling_mask, torch.finfo(track_entropy.dtype).max
            )
            _, indices = track_entropy.topk(num_to_sample, dim=-1, largest=False)
            is_top_k = ~(
                torch.arange(sequence_length, device=device)[:, None]
                != indices[None, :]
            ).all(-1)
            tokens_to_sample = sampling_mask & is_top_k

            old_track_samples = getattr(sampled_tokens, current_track)
            new_track_samples = getattr(new_samples, current_track)

            new_track_samples = torch.where(
                tokens_to_sample, new_track_samples, old_track_samples
            )

            setattr(sampled_tokens, current_track, new_track_samples)

    # Do not update tracks that were not sampled (e.g. keep None instead of masks)
    for current_track in all_tracks:
        if current_track != track_to_sample:
            setattr(
                sampled_tokens,
                current_track,
                maybe_clone(getattr(input_tokens, current_track)),
            )

    return sampled_tokens
