FROM nvcr.io/nvidia/clara/bionemo-framework:1.10
WORKDIR /workspace/bionemo

RUN pip install --no-cache-dir build

RUN git clone https://github.com/A-Alpha-Bio/alphabind

# NOTE: The constraints.txt file ensures that we preserve the exact versions of
# low-level ML dependencies distributed in the base image.
RUN set -o pipefail \
    && cd alphabind/alphabind \
    && python -m build \
    && python -m pip list --format freeze | egrep "torch|nvidia|cuda" > constraints.txt \
    && python -m pip install --no-cache-dir -c constraints.txt ./dist/alphabind-*-py3-*.whl
