"""
segmentasi semantik 1 citra dengan model hasil fine-tuning CamVid (camvid_train.ipynb).
dipanggil dari MATLAB (semanticSegmentation.m) lewat system().

pemakaian:
    python camvid_predict.py --model model/camvid_deeplabv3_mbv3.pth --image in.png --out label.png

output:
    label.png - citra 1 kanal uint8, ukuran sama dengan citra masukan,
                nilai 0..10 = indeks kelas sesuai urutan class_names di checkpoint
"""
import argparse

import numpy as np
import torch
from PIL import Image
from torchvision.models.segmentation import deeplabv3_mobilenet_v3_large


def load_model(model_path):
    # checkpoint berisi bobot + info kelas & preprocessing (lihat save_checkpoint di notebook)
    ckpt = torch.load(model_path, map_location="cpu")

    # arsitektur dibuat kosong (tanpa download bobot), lalu diisi bobot hasil fine-tuning
    model = deeplabv3_mobilenet_v3_large(weights=None, weights_backbone=None,
                                         num_classes=len(ckpt["class_names"]), aux_loss=False)
    model.load_state_dict(ckpt["state_dict"])
    model.eval()
    return model, ckpt


def predict(model, ckpt, img):
    """img: PIL RGB ukuran bebas -> label (H x W) uint8 ukuran sama dengan img"""
    H, W = ckpt["input_size"]

    # preprocessing harus sama persis dengan saat training: resize -> [0,1] -> normalisasi
    x = np.asarray(img.resize((W, H), Image.BILINEAR), dtype=np.float32) / 255.0
    x = (x - np.array(ckpt["mean"])) / np.array(ckpt["std"])
    x = torch.from_numpy(x.transpose(2, 0, 1)).float().unsqueeze(0)   # 1 x 3 x H x W

    with torch.no_grad():
        logits = model(x)["out"]                       # 1 x 11 x H x W
    label = logits.argmax(1)[0].numpy().astype(np.uint8)   # kelas dengan skor tertinggi per piksel

    # kembalikan ke ukuran citra asli, NEAREST supaya indeks kelas tidak tercampur
    return np.asarray(Image.fromarray(label).resize(img.size, Image.NEAREST))


def main():
    parser = argparse.ArgumentParser(description="segmentasi semantik CamVid 1 citra")
    parser.add_argument("--model", required=True, help="path file .pth hasil training")
    parser.add_argument("--image", required=True, help="path citra masukan")
    parser.add_argument("--out", required=True, help="path PNG label keluaran")
    args = parser.parse_args()

    model, ckpt = load_model(args.model)
    img = Image.open(args.image).convert("RGB")   # grayscale / RGBA -> RGB
    label = predict(model, ckpt, img)
    Image.fromarray(label).save(args.out)


if __name__ == "__main__":
    main()
