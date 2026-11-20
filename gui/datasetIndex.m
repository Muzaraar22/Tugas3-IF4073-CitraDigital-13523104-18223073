function index = datasetIndex(dataFolder)
% datasetIndex - daftar sumber citra uji yang tersedia
%
% dataFolder : folder data repo (berisi BSDS500/ dan CamVid/)
% index      : struct array dengan field
%                .name  : nama sumber untuk dropdown
%                .path  : folder citra
%                .files : cell array nama file citra, terurut abjad
%              sumber yang foldernya tidak ada / kosong dilewati

sources = {
    'BSDS500 (Bagian B & C)',   fullfile(dataFolder, 'BSDS500')
    'CamVid test (Bagian D)',   fullfile(dataFolder, 'CamVid', 'test')
};

index = struct('name', {}, 'path', {}, 'files', {});

for k = 1:size(sources, 1)
    files = listImages(sources{k, 2});
    if isempty(files)
        continue;
    end
    index(end + 1) = struct('name', sources{k, 1}, 'path', sources{k, 2}, ...
                            'files', {files}); %#ok<AGROW>
end
end

function names = listImages(folder)
% semua file citra (jpg/png/bmp/tif) di folder, terurut abjad
names = {};
if ~isfolder(folder)
    return;
end
exts = {'*.jpg', '*.jpeg', '*.png', '*.bmp', '*.tif', '*.tiff'};
for e = 1:numel(exts)
    files = dir(fullfile(folder, exts{e}));
    names = [names, {files.name}]; %#ok<AGROW>
end
names = sort(unique(names));
end
