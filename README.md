# IndicTrans2 INT8 Quantization

## Offline CPU-Based Multilingual Translation

This project provides an **INT8-quantized IndicTrans2 model** for CPU-based and offline translation.

The original IndicTrans2 model was loaded in **FP32** and converted using **PyTorch Dynamic INT8 Quantization**. The resulting quantized model is approximately **1.49 GB**, making it more practical for local and offline deployment.

---

## 🚀 Highlights

- IndicTrans2 English → Indic translation model
- FP32 → INT8 dynamic quantization
- CPU-based inference
- Offline translation
- 289 quantized Linear layers
- 158,902,272 quantized Linear parameters
- INT8 model size: **~1.49 GB**
- Tested with English, Hindi, Telugu, Tamil, and Bengali
- Target translation language: **Santali**

---

## 📥 Download the INT8 Model

The pre-quantized model is available as a GitHub Release asset.

### IndicTrans2 INT8 v1.0.0

| Property | Value |
|---|---|
| Model | IndicTrans2 INT8 |
| File | `indictrans2-int8.pth` |
| Size | ~1.49 GB |
| Format | PyTorch `.pth` |
| Inference | CPU |
| Release | v1.0.0 |

### Download

**[⬇️ Download IndicTrans2 INT8 v1.0.0](https://github.com/puneeth24-pk/QUANTIZE8_INDICTRANS2/releases/tag/v1.0.0)**

After downloading, place the model file in the project directory:

```text
QUANTIZE8_INDICTRANS2/
│
├── indictrans2-int8.pth
├── test.py
├── quantize.py
├── quantize2.py
├── quantize3.py
├── int8_test.py
└── README.md
