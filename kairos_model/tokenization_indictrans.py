import os
import json

from transformers.utils import logging
from typing import Dict, List, Optional, Union, Tuple

from sentencepiece import SentencePieceProcessor
from transformers.tokenization_utils import PreTrainedTokenizer


logger = logging.get_logger(__name__)

# Convert LANGUAGE_TAGS to a frozen set for faster lookups
LANGUAGE_TAGS = frozenset(
    {
        "asm_Beng",
        "awa_Deva",
        "ben_Beng",
        "bho_Deva",
        "brx_Deva",
        "doi_Deva",
        "eng_Latn",
        "gom_Deva",
        "gon_Deva",
        "guj_Gujr",
        "hin_Deva",
        "hne_Deva",
        "kan_Knda",
        "kas_Arab",
        "kas_Deva",
        "kha_Latn",
        "lus_Latn",
        "mag_Deva",
        "mai_Deva",
        "mal_Mlym",
        "mar_Deva",
        "mni_Beng",
        "mni_Mtei",
        "npi_Deva",
        "ory_Orya",
        "pan_Guru",
        "san_Deva",
        "sat_Olck",
        "snd_Arab",
        "snd_Deva",
        "tam_Taml",
        "tel_Telu",
        "urd_Arab",
        "unr_Deva",
    }
)

VOCAB_FILES_NAMES = {
    "src_vocab_fp": "dict.SRC.json",
    "tgt_vocab_fp": "dict.TGT.json",
    "src_spm_fp": "model.SRC",
    "tgt_spm_fp": "model.TGT",
}


class IndicTransTokenizer(PreTrainedTokenizer):
    _added_tokens_encoder: Dict[str, int] = {}
    _added_tokens_decoder: Dict[str, int] = {}
    vocab_files_names = VOCAB_FILES_NAMES
    model_input_names = ["input_ids", "attention_mask"]

    def __init__(
        self,
        src_vocab_fp=None,
        tgt_vocab_fp=None,
        src_spm_fp=None,
        tgt_spm_fp=None,
        unk_token="<unk>",
        bos_token="<s>",
        eos_token="</s>",
        pad_token="<pad>",
        do_lower_case=False,
        **kwargs,
    ):
        self.src_vocab_fp = src_vocab_fp
        self.tgt_vocab_fp = tgt_vocab_fp
        self.src_spm_fp = src_spm_fp
        self.tgt_spm_fp = tgt_spm_fp

        # Store token content directly instead of accessing .content
        self.unk_token = (
            hasattr(unk_token, "content") and unk_token.content or unk_token
        )
        self.pad_token = (
            hasattr(pad_token, "content") and pad_token.content or pad_token
        )
        self.eos_token = (
            hasattr(eos_token, "content") and eos_token.content or eos_token
        )
        self.bos_token = (
            hasattr(bos_token, "content") and bos_token.content or bos_token
        )

        # Load vocabularies
        self.src_encoder = self._load_json(self.src_vocab_fp)
        self.tgt_encoder = self._load_json(self.tgt_vocab_fp)

        # Validate tokens
        if self.unk_token not in self.src_encoder:
            raise KeyError("<unk> token must be in vocab")
        if self.pad_token not in self.src_encoder:
            raise KeyError("<pad> token must be in vocab")

        # Pre-compute reverse mappings
        self.src_decoder = {v: k for k, v in self.src_encoder.items()}
        self.tgt_decoder = {v: k for k, v in self.tgt_encoder.items()}

        # Load SPM models
        self.src_spm = self._load_spm(self.src_spm_fp)
        self.tgt_spm = self._load_spm(self.tgt_spm_fp)

        # Initialize current settings
        self._switch_to_input_mode()

        # Cache token IDs
        self.unk_token_id = self.src_encoder[self.unk_token]
        self.pad_token_id = self.src_encoder[self.pad_token]
        self.eos_token_id = self.src_encoder[self.eos_token]
        self.bos_token_id = self.src_encoder[self.bos_token]

        super().__init__(
            src_vocab_file=self.src_vocab_fp,
            tgt_vocab_file=self.tgt_vocab_fp,
            do_lower_case=do_lower_case,
            unk_token=unk_token,
            bos_token=bos_token,
            eos_token=eos_token,
            pad_token=pad_token,
            **kwargs,
        )

    def add_new_language_tags(self, new_tags: List[str]) -> None:
        global LANGUAGE_TAGS
        LANGUAGE_TAGS = frozenset(LANGUAGE_TAGS | set(new_tags))

    def _switch_to_input_mode(self) -> None:
        self.spm = self.src_spm
        self.padding_side = "left"
        self.encoder = self.src_encoder
        self.decoder = self.src_decoder
        self._tokenize = self._src_tokenize

    def _switch_to_target_mode(self) -> None:
        self.spm = self.tgt_spm
        self.padding_side = "right"
        self.encoder = self.tgt_encoder
        self.decoder = self.tgt_decoder
        self._tokenize = self._tgt_tokenize

    @staticmethod
    def _load_spm(path: str) -> SentencePieceProcessor:
        return SentencePieceProcessor(model_file=path)

    @staticmethod
    def _save_json(data: Union[Dict, List], path: str) -> None:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)

    @staticmethod
    def _load_json(path: str) -> Union[Dict, List]:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)

    @property
    def src_vocab_size(self) -> int:
        return len(self.src_encoder)

    @property
    def tgt_vocab_size(self) -> int:
        return len(self.tgt_encoder)

    def get_src_vocab(self) -> Dict[str, int]:
        return dict(self.src_encoder, **self.added_tokens_encoder)

    def get_tgt_vocab(self) -> Dict[str, int]:
        return dict(self.tgt_encoder, **self.added_tokens_decoder)

    def get_vocab(self) -> Dict[str, int]:
        return self.get_src_vocab()

    @property
    def vocab_size(self) -> int:
        return self.src_vocab_size

    def _convert_token_to_id(self, token: str) -> int:
        return self.encoder.get(token, self.unk_token_id)

    def _convert_id_to_token(self, index: int) -> str:
        return self.decoder.get(index, self.unk_token)

    def convert_tokens_to_string(self, tokens: List[str]) -> str:
        return "".join(tokens).replace("▁", " ").strip()

    def _src_tokenize(self, text: str) -> List[str]:
        src_lang, tgt_lang, text = text.split(" ", 2)
        assert src_lang in LANGUAGE_TAGS, f"Invalid source language tag: {src_lang}"
        assert tgt_lang in LANGUAGE_TAGS, f"Invalid target language tag: {tgt_lang}"
        return [src_lang, tgt_lang] + self.spm.EncodeAsPieces(text)

    def _tgt_tokenize(self, text: str) -> List[str]:
        return self.spm.EncodeAsPieces(text)

    def _decode(
        self,
        token_ids: Union[int, List[int]],
        skip_special_tokens: bool = False,
        clean_up_tokenization_spaces: bool = None,
        spaces_between_special_tokens: bool = True,
        **kwargs,
    ) -> str:
        self._switch_to_target_mode()
        decoded_token_ids = super()._decode(
            token_ids=token_ids,
            skip_special_tokens=skip_special_tokens,
            clean_up_tokenization_spaces=clean_up_tokenization_spaces,
            spaces_between_special_tokens=spaces_between_special_tokens,
            **kwargs,
        )
        self._switch_to_input_mode()
        return decoded_token_ids

    def build_inputs_with_special_tokens(
        self, token_ids_0: List[int], token_ids_1: Optional[List[int]] = None
    ) -> List[int]:
        return token_ids_0 + [self.eos_token_id]

    def save_vocabulary(
        self, save_directory: str, filename_prefix: Optional[str] = None
    ) -> Tuple[str, ...]:
        if not os.path.isdir(save_directory):
            logger.error(f"Vocabulary path ({save_directory}) should be a directory")
            return ()

        src_spm_fp = os.path.join(save_directory, "model.SRC")
        tgt_spm_fp = os.path.join(save_directory, "model.TGT")
        src_vocab_fp = os.path.join(save_directory, "dict.SRC.json")
        tgt_vocab_fp = os.path.join(save_directory, "dict.TGT.json")

        self._save_json(self.src_encoder, src_vocab_fp)
        self._save_json(self.tgt_encoder, tgt_vocab_fp)

        for fp, spm in [(src_spm_fp, self.src_spm), (tgt_spm_fp, self.tgt_spm)]:
            with open(fp, "wb") as f:
                f.write(spm.serialized_model_proto())

        return src_vocab_fp, tgt_vocab_fp, src_spm_fp, tgt_spm_fp
