import torch

from transformers import AutoTokenizer

from model import load_int8_model


DEVICE = torch.device("cpu")

MODEL_FILES = "./model_files"


def translate(model, tokenizer, text, src_lang, tgt_lang):

    tokenizer.src_lang = src_lang

    inputs = tokenizer(
        text,
        return_tensors="pt"
    )

    with torch.no_grad():
        output = model.generate(
            **inputs,
            max_length=256
        )

    result = tokenizer.batch_decode(
        output,
        skip_special_tokens=True
    )[0]

    return result


def main():

    print("================================")
    print("   IndicTrans2 INT8 Translator")
    print("================================")

    model = load_int8_model()

    tokenizer = AutoTokenizer.from_pretrained(
        MODEL_FILES,
        trust_remote_code=True
    )

    src_lang = input("Source language code: ")
    tgt_lang = input("Target language code: ")

    text = input("Enter text: ")

    result = translate(
        model,
        tokenizer,
        text,
        src_lang,
        tgt_lang
    )

    print("\nTranslation:")
    print(result)


if __name__ == "__main__":
    main()
