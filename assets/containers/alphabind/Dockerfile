FROM nvcr.io/nvidia/clara/bionemo-framework:1.10
WORKDIR /workspace/bionemo

RUN pip install --no-cache-dir build

ADD ./alphabind ./alphabind

# NOTE: The constraints.txt file ensures that we preserve the exact versions of
# low-level ML dependencies distributed in the base image.
RUN cd alphabind \
    && python3 -m build \
    && python -m pip list --format freeze | egrep "torch|nvidia|cuda" > constraints.txt \
    && python -m pip install --no-cache-dir -c constraints.txt ./dist/alphabind-*-py3-*.whl
