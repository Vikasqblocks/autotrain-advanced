FROM nvidia/cuda:12.1.0-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC

ENV PATH="${HOME}/miniconda3/bin:${PATH}"
ARG PATH="${HOME}/miniconda3/bin:${PATH}"

RUN mkdir -p /tmp/model
RUN chown -R 1000:1000 /tmp/model
RUN mkdir -p /tmp/data
RUN chown -R 1000:1000 /tmp/data

RUN apt-get update &&  \
    apt-get upgrade -y &&  \
    apt-get install -y \
    build-essential \
    cmake \
    curl \
    ca-certificates \
    gcc \
    git \
    locales \
    net-tools \
    wget \
    libpq-dev \
    libsndfile1-dev \
    git \
    git-lfs \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*


RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
    git lfs install

WORKDIR /app
RUN mkdir -p /app/.cache
ENV HF_HOME="/app/.cache"
RUN chown -R 1000:1000 /app
USER 1000
ENV HOME=/app

ENV PYTHONPATH=$HOME/app \
    PYTHONUNBUFFERED=1 \
    GRADIO_ALLOW_FLAGGING=never \
    GRADIO_NUM_PORTS=1 \
    GRADIO_SERVER_NAME=0.0.0.0 \
    SYSTEM=spaces


RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && sh Miniconda3-latest-Linux-x86_64.sh -b -p /app/miniconda \
    && rm -f Miniconda3-latest-Linux-x86_64.sh
ENV PATH /app/miniconda/bin:$PATH

RUN conda create -p /app/env -y python=3.10

SHELL ["conda", "run","--no-capture-output", "-p","/app/env", "/bin/bash", "-c"]

RUN conda install pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia && conda clean -ya
COPY --chown=1000:1000 . /app/

RUN pip install -e .

RUN python -m nltk.downloader punkt
RUN autotrain setup
RUN pip install flash-attn

CMD autotrain llm \
    --train \
    --model ${MODEL_NAME} \
    --project-name ${PROJECT_NAME} \
    --data-path data/ \
    --text-column text \
    --lr ${LEARNING_RATE} \
    --batch-size ${BATCH_SIZE} \
    --epochs ${NUM_EPOCHS} \
    --block-size ${BLOCK_SIZE} \
    --warmup-ratio ${WARMUP_RATIO} \
    --lora-r ${LORA_R} \
    --lora-alpha ${LORA_ALPHA} \
    --lora-dropout ${LORA_DROPOUT} \
    --weight-decay ${WEIGHT_DECAY} \
    --gradient-accumulation ${GRADIENT_ACCUMULATION} \
    $( [[ "$USE_FP16" == "True" ]] && echo "--fp16" ) \
    $( [[ "$USE_PEFT" == "True" ]] && echo "--use-peft" ) \
    $( [[ "$USE_INT4" == "True" ]] && echo "--use-int4" ) \
    $( [[ "$PUSH_TO_HUB" == "True" ]] && echo "--push-to-hub --token ${HF_TOKEN} --repo-id ${REPO_ID}" )