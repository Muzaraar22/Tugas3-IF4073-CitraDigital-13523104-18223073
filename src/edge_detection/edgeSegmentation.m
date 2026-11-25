function res = edgeSegmentation(I, method, params)
% pipeline deteksi tepi -> segmentasi objek
%
% INPUT:
%   I      - citra masukan (RGB / grayscale)
%   method - 'laplace' / 'log' / 'sobel' / 'prewitt' / 'roberts' / 'canny'
%   params - (opsional) gabungan parameter detectEdges.m dan segmentFromEdges.m
%
% OUTPUT:
%   res - struct:
%     .response      - respons operator sebelum diambang (double 0..1)
%     .thresholdText - ambang yang dipakai, mis. 'Otsu, T = 0.143'
%     .edges         - citra tepi biner
%     .mask          - mask objek hasil segmentasi
%     .segmented     - objek saja, latar belakang hitam
%     .overlay       - citra asli + garis batas objek (merah)
%     .steps         - citra antara segmentasi (lihat segmentFromEdges.m)

if nargin < 3
    params = struct();
end

[res.edges, info] = detectEdges(I, method, params);
res.response      = info.response;
res.thresholdText = info.modeText;
[res.mask, res.steps] = segmentFromEdges(res.edges, params);

% citra asli versi RGB double, supaya bisa dikali mask & diberi warna
Irgb = im2double(I);
if size(Irgb, 3) == 1
    Irgb = repmat(Irgb, [1 1 3]);
end

res.segmented = Irgb .* res.mask;   % latar belakang jadi 0

% garis batas objek, ditebalkan sedikit agar keliatan
boundary = imdilate(bwperim(res.mask), ones(3));
res.overlay = imoverlay(Irgb, boundary, 'red');
end
