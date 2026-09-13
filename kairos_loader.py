import os
import torch

from transformers import AutoConfig, AutoModelForSeq2SeqLM, AutoTokenizer
from IndicTransToolkit.processor import IndicProcessor

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

MODEL_DIR = os.path.join(BASE_DIR, "kairos_model")
INT8_WEIGHTS = os.path.join(BASE_DIR, "indictrans2-int8", "indictrans2-int8.pth")

DEVICE = torch.device("cpu")

torch.backends.quantized.engine = "qnnpack"


def load_int8_model():
    print("Loading KAIROS INT8 model...")

    config = AutoConfig.from_pretrained(
        MODEL_DIR,
        trust_remote_code=True
    )

    model = AutoModelForSeq2SeqLM.from_config(
        config,
        trust_remote_code=True
    )

    model.eval()

    model = torch.ao.quantization.quantize_dynamic(
        model,
        {torch.nn.Linear},
        dtype=torch.qint8
    )

    state_dict = torch.load(
        INT8_WEIGHTS,
        map_location="cpu",
        weights_only=False
    )

    model.load_state_dict(state_dict)
    model.eval()

    tokenizer = AutoTokenizer.from_pretrained(
        MODEL_DIR,
        trust_remote_code=True
    )

    processor = IndicProcessor(inference=True)

    print("KAIROS INT8 model loaded successfully.")

    return model, tokenizer, processor


def translate(model, tokenizer, processor, text, src_lang, tgt_lang):
    batch = processor.preprocess_batch(
        [text],
        src_lang=src_lang,
        tgt_lang=tgt_lang
    )

    inputs = tokenizer(
        batch,
        padding="longest",
        truncation=True,
        max_length=256,
        return_tensors="pt"
    )

    with torch.inference_mode():
        generated_tokens = model.generate(
            **inputs,
            use_cache=True,
            max_length=256,
            num_beams=5,
            num_return_sequences=1
        )

    decoded = tokenizer.batch_decode(
        generated_tokens,
        skip_special_tokens=True
    )

    output = processor.postprocess_batch(
        decoded,
        lang=tgt_lang
    )

    return output[0]