import torch
from transformers import AutoModelForSeq2SeqLM


# CPU only
DEVICE = torch.device("cpu")

# Local FP32 model is used only to recreate the model architecture.
FP32_MODEL = "../indictrans2-en-indic-1B"

# Our saved INT8 weights
INT8_WEIGHTS = "../indictrans2-int8/indictrans2-int8.pth"


def load_int8_model():

    print("Loading INT8 model...")

    # QNNPACK is required for INT8 CPU quantization
    torch.backends.quantized.engine = "qnnpack"

    # Load model architecture
    model = AutoModelForSeq2SeqLM.from_pretrained(
        FP32_MODEL,
        torch_dtype=torch.float32,
        trust_remote_code=True
    )

    model.eval()

    # Recreate the same dynamic INT8 structure
    model = torch.ao.quantization.quantize_dynamic(
        model,
        {torch.nn.Linear},
        dtype=torch.qint8
    )

    # Load our saved INT8 weights
    state_dict = torch.load(
        INT8_WEIGHTS,
        map_location=DEVICE
    )

    model.load_state_dict(state_dict)

    model.eval()

    print("INT8 model loaded successfully.")

    return model

if __name__ == "__main__":


    model = load_int8_model()