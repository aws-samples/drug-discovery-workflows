import clize
import requests
import torch

from esm.sdk.api import (
    ESM3InferenceClientV1,
    ESMProtein,
    ESMProteinTensor,
    ForwardAndSampleOutput,
    ForwardOutput,
    ForwardTrackData,
    GenerationConfig,
    ReturnLogitsConfig,
    SamplingConfig,
    SamplingTrackConfig,
)
from esm.utils.generation import iterative_sampling_raw


class ESM3ForgeInferenceClient(ESM3InferenceClientV1):
    def __init__(self, model, url, token):
        self.model = model
        self.url = url
        self.token = token
        self.headers = {"Authorization": f"Bearer {self.token}"}

    def generate(self, input: ESMProtein, config: GenerationConfig) -> ESMProtein:
        raw_protein = iterative_sampling_raw(self, input, config)
        return raw_protein

    def iterative_sampling(
        self, input: ESMProteinTensor, config: GenerationConfig
    ) -> ESMProteinTensor:
        raise NotImplementedError

    def _forward(
        self,
        input: ESMProteinTensor,
        return_logits: ReturnLogitsConfig = ReturnLogitsConfig(),
        return_embeddings: bool = False,
    ) -> ForwardOutput:
        raise NotImplementedError

    def forward_and_sample(
        self, input: ESMProteinTensor, sampling_configuration: SamplingConfig
    ) -> ForwardAndSampleOutput:
        req = {}
        sampling_config = {}
        embedding_config = None  # TODO(zeming)

        def tolist(x):
            return x.tolist() if x is not None else None

        req["sequence"] = tolist(input.sequence)
        req["structure"] = tolist(input.structure)
        req["secondary_structure"] = tolist(input.secondary_structure)
        req["sasa"] = tolist(input.sasa)
        req["function"] = tolist(input.function)
        req["coords"] = tolist(input.coordinates)
        req["residue_annotation"] = tolist(input.residue_annotations)
        req["confidence"] = tolist(input.confidence)

        def do_track(t: str):
            track: SamplingTrackConfig | None
            if (track := getattr(sampling_configuration, t, None)) is None:
                sampling_config[t] = None
            else:
                sampling_config[t] = {
                    "temperature": track.temperature,
                    "top_p": track.top_p,
                    "only_sample_masked_tokens": track.only_sample_masked_tokens,
                    "invalid_ids": track.invalid_ids,
                    "topk_logprobs": track.topk_logprobs,
                }

        do_track("sequence")
        do_track("structure")
        do_track("secondary_structure")
        do_track("sasa")
        do_track("function")

        request = {
            "model": self.model,
            "inputs": req,
            "sampling_config": sampling_config,
            "embedding_config": embedding_config,
        }
        data = self.__post("forward_and_sample", request)

        def get(k, field):
            if data[k] is None:
                return None
            v = data[k][field]
            return torch.tensor(v) if v is not None else None

        tokens = ESMProteinTensor(
            sequence=get("sequence", "tokens"),
            structure=get("structure", "tokens"),
            secondary_structure=get("secondary_structure", "tokens"),
            sasa=get("sasa", "tokens"),
            function=get("function", "tokens"),
        )

        def get_track(field):
            return ForwardTrackData(
                sequence=get("sequence", field),
                structure=get("structure", field),
                secondary_structure=get("secondary_structure", field),
                sasa=get("sasa", field),
                function=get("function", field),
            )

        def operate_on_track(track: ForwardTrackData, fn):
            apply = lambda x: fn(x) if x is not None else None
            return ForwardTrackData(
                sequence=apply(track.sequence),
                structure=apply(track.structure),
                secondary_structure=apply(track.secondary_structure),
                sasa=apply(track.sasa),
                function=apply(track.function),
            )

        logprob = get_track("logprobs")
        output = ForwardAndSampleOutput(
            protein_tensor=tokens,
            logprob=logprob,
            prob=operate_on_track(logprob, torch.exp),
            entropy=get_track("entropy"),
            topk_logprob=get_track("topk_logprobs"),
            topk_tokens=get_track("topk_tokens"),
        )
        return output

    def encode(
        self, input: ESMProtein, override_structure_tokens_with_coords: bool = True
    ) -> ESMProteinTensor:
        tracks = {}
        tracks["sequence"] = input.sequence
        # TODO: Remove this from forge request, use coordinates instead
        tracks["structure"] = None
        tracks["secondary_structure"] = input.secondary_structure
        tracks["sasa"] = input.sasa
        if input.function_annotations is not None:
            tracks["function"] = [x.to_tuple() for x in input.function_annotations]
        # TODO(zeming) input.override_structure_tokens_with_coords?? Is this supported?
        request = {"inputs": tracks, "model": self.model}

        data = self.__post("encode", request)

        def t(x):
            return torch.tensor(x) if x is not None else None

        return ESMProteinTensor(
            sequence=t(data["outputs"]["sequence"]),
            structure=t(data["outputs"]["structure"]),
            coordinates=t(data["outputs"]["coords"]),
            secondary_structure=t(data["outputs"]["secondary_structure"]),
            sasa=t(data["outputs"]["sasa"]),
            function=t(data["outputs"]["function"]),
            residue_annotations=t(data["outputs"]["residue_annotation"]),
            # TODO(zeming): plddt? Confidence?
            # TODO: Handle coordinates too
        )

    def decode(
        self,
        input: ESMProteinTensor,
        override_structure_tokens_with_coords: bool = False,
    ) -> ESMProtein:
        def tolist(x):
            return x.tolist() if x is not None else None

        tokens = {}
        tokens["sequence"] = tolist(input.sequence)
        tokens["structure"] = tolist(input.structure)
        tokens["secondary_structure"] = tolist(input.secondary_structure)
        tokens["sasa"] = tolist(input.sasa)
        tokens["function"] = tolist(input.function)
        tokens["residue_annotation"] = tolist(input.residue_annotations)

        request = {"inputs": tokens, "model": self.model}

        data = self.__post("decode", request)
        return ESMProtein(
            sequence=data["outputs"]["sequence"],
            secondary_structure=data["outputs"]["secondary_structure"],
            sasa=data["outputs"]["sasa"],
            function_annotations=data["outputs"]["function"],
            # TODO: Handle coordinates
        )

    def __post(self, endpoint, request):
        response = requests.post(
            f"{self.url}/sdk/v1/{endpoint}", json=request, headers=self.headers
        )

        if not response.ok:
            raise RuntimeError(f"Failure in {endpoint}: {response.json()['message']}")

        return response.json()["data"]


def main(url: str, api_key: str):
    client = ESM3ForgeInferenceClient("esm3-sm-open-v1", url, api_key)

    seq = "MSHHWGYGKHNGPEHWHKDFPIAKGERQSPVDIDTHTAKYDPSLKPLSVSYDQATSLRILNNGHAFNVEFDDSQDKAVLKGGPLDGTYRLIQFHFHWGSLDGQGSEHTVDKKKYAAELHLVHWNTKYGDFGKAVQQPDGLAVLGIFLKVGSAKPGLQKVVDVLDSIKTKGKSADFTNFDPRGLLPESLDYWTYPGSLTTPPLLECVTWIVLKEPISVSSEQVLKFRKLNFNGEGEPEELMVDNWRPAQPLKNRQIKASFK"
    to_encode = ESMProtein(sequence=seq)

    encoded = client.encode(to_encode)
    sampled = client.forward_and_sample(
        encoded,
        SamplingConfig(structure=SamplingTrackConfig(temperature=0.7, topk_logprobs=2)),
    )
    assert sampled.protein_tensor is not None
    print(sampled.topk_logprob)
    decoded = client.decode(
        ESMProteinTensor(
            sequence=encoded.sequence, structure=sampled.protein_tensor.structure
        )
    )
    print(decoded.coordinates)


if __name__ == "__main__":
    clize.run(main)
