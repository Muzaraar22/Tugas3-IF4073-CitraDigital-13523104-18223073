function test_split_merge_gui()
% test_split_merge_gui GUI interaktif untuk menguji dan mengatur parameter
%                      segmentasi Split and Merge pada citra BSDS500.

    % Deteksi path proyek secara otomatis
    testDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(testDir);
    addpath(genpath(fullfile(rootDir, 'src')));

    dataDir = fullfile(rootDir, 'data', 'BSDS500');
    outDir  = fullfile(rootDir, 'results', 'split_merge');

    % Ambil daftar citra BSDS500
    imgFiles = dir(fullfile(dataDir, '*.jpg'));
    if isempty(imgFiles)
        fileNames = {'(Tidak ada citra di data/BSDS500)'};
    else
        fileNames = {imgFiles.name};
    end

    % State aplikasi yang dibagikan antar-callback
    state.currentImg  = [];
    state.currentName = '';
    state.lastInfo    = [];

    % --- Inisialisasi Jendela Utama ---
    fig = figure('Name', 'Pengujian Interaktif Split & Merge - IF4073', ...
                 'NumberTitle', 'off', ...
                 'MenuBar', 'none', ...
                 'ToolBar', 'figure', ...
                 'Position', [70, 70, 1280, 640], ...
                 'Color', [0.94, 0.94, 0.94]);

    % --- 4 Panel Tampilan Citra ---
    ax1 = axes('Parent', fig, 'Position', [0.025, 0.34, 0.22, 0.58]);
    ax2 = axes('Parent', fig, 'Position', [0.268, 0.34, 0.22, 0.58]);
    ax3 = axes('Parent', fig, 'Position', [0.511, 0.34, 0.22, 0.58]);
    ax4 = axes('Parent', fig, 'Position', [0.754, 0.34, 0.22, 0.58]);

    % --- Panel Kontrol Bawah ---
    pnl = uipanel('Parent', fig, 'Title', 'Pengaturan Parameter Split & Merge', ...
                  'FontSize', 10, 'FontWeight', 'bold', ...
                  'Position', [0.025, 0.03, 0.95, 0.26]);

    % Kolom 1: Pemilihan Citra, Predikat, dan MinBlockSize
    uicontrol('Parent', pnl, 'Style', 'text', 'String', 'Citra Uji:', ...
              'HorizontalAlignment', 'left', 'Units', 'normalized', ...
              'Position', [0.015, 0.72, 0.08, 0.16]);
    ddImage = uicontrol('Parent', pnl, 'Style', 'popupmenu', 'String', fileNames, ...
                        'Units', 'normalized', 'Position', [0.095, 0.73, 0.16, 0.17], ...
                        'Callback', @onSelectImage);
    uicontrol('Parent', pnl, 'Style', 'pushbutton', 'String', 'Browse...', ...
              'Units', 'normalized', 'Position', [0.262, 0.73, 0.065, 0.17], ...
              'Callback', @onBrowseImage);

    uicontrol('Parent', pnl, 'Style', 'text', 'String', 'Predikat Q(R):', ...
              'HorizontalAlignment', 'left', 'Units', 'normalized', ...
              'Position', [0.015, 0.42, 0.08, 0.16]);
    ddPred = uicontrol('Parent', pnl, 'Style', 'popupmenu', ...
                       'String', {'std', 'range'}, 'Value', 1, ...
                       'Units', 'normalized', 'Position', [0.095, 0.43, 0.10, 0.17], ...
                       'Callback', @(~, ~) runSegmentation());

    uicontrol('Parent', pnl, 'Style', 'text', 'String', 'Min Block Size:', ...
              'HorizontalAlignment', 'left', 'Units', 'normalized', ...
              'Position', [0.015, 0.12, 0.08, 0.16]);
    ddBlock = uicontrol('Parent', pnl, 'Style', 'popupmenu', ...
                        'String', {'2', '4', '8', '16'}, 'Value', 2, ...
                        'Units', 'normalized', 'Position', [0.095, 0.13, 0.10, 0.17], ...
                        'Callback', @(~, ~) runSegmentation());

    % Kolom 2: Kontrol Threshold Split & Merge
    uicontrol('Parent', pnl, 'Style', 'text', 'String', 'Split Threshold:', ...
              'HorizontalAlignment', 'left', 'Units', 'normalized', ...
              'Position', [0.355, 0.72, 0.095, 0.16]);
    sldSplit = uicontrol('Parent', pnl, 'Style', 'slider', ...
                         'Min', 0.005, 'Max', 0.50, 'Value', 0.06, ...
                         'Units', 'normalized', 'Position', [0.455, 0.74, 0.18, 0.14], ...
                         'Callback', @onSplitSlider);
    edtSplit = uicontrol('Parent', pnl, 'Style', 'edit', 'String', '0.060', ...
                         'Units', 'normalized', 'Position', [0.642, 0.73, 0.055, 0.17], ...
                         'Callback', @onSplitEdit);

    uicontrol('Parent', pnl, 'Style', 'text', 'String', 'Merge Threshold:', ...
              'HorizontalAlignment', 'left', 'Units', 'normalized', ...
              'Position', [0.355, 0.42, 0.095, 0.16]);
    sldMerge = uicontrol('Parent', pnl, 'Style', 'slider', ...
                         'Min', 0.005, 'Max', 0.50, 'Value', 0.08, ...
                         'Units', 'normalized', 'Position', [0.455, 0.44, 0.18, 0.14], ...
                         'Callback', @onMergeSlider);
    edtMerge = uicontrol('Parent', pnl, 'Style', 'edit', 'String', '0.080', ...
                         'Units', 'normalized', 'Position', [0.642, 0.43, 0.055, 0.17], ...
                         'Callback', @onMergeEdit);

    chkLock = uicontrol('Parent', pnl, 'Style', 'checkbox', ...
                        'String', 'Samakan Split & Merge Threshold (Predikat Tunggal Q)', ...
                        'Value', 0, 'Units', 'normalized', ...
                        'Position', [0.355, 0.12, 0.34, 0.18], ...
                        'Callback', @onToggleLock);

    % Kolom 3: Status Hasil & Tombol Aksi
    txtStatus = uicontrol('Parent', pnl, 'Style', 'text', ...
                          'String', 'Memuat citra pertama...', ...
                          'HorizontalAlignment', 'left', 'FontSize', 9, ...
                          'BackgroundColor', [1, 1, 1], ...
                          'Units', 'normalized', 'Position', [0.72, 0.42, 0.26, 0.48]);

    uicontrol('Parent', pnl, 'Style', 'pushbutton', 'String', 'Proses Ulang', ...
              'FontWeight', 'bold', 'Units', 'normalized', ...
              'Position', [0.72, 0.11, 0.115, 0.23], ...
              'Callback', @(~, ~) runSegmentation());

    uicontrol('Parent', pnl, 'Style', 'pushbutton', 'String', 'Simpan ke Results', ...
              'FontWeight', 'bold', 'Units', 'normalized', ...
              'Position', [0.845, 0.11, 0.135, 0.23], ...
              'Callback', @onSaveResult);

    % Muat citra awal jika tersedia
    if ~isempty(imgFiles)
        loadImageFile(fullfile(dataDir, imgFiles(1).name), imgFiles(1).name);
    end

    % ================= CALLBACKS =================

    function onSelectImage(src, ~)
        if isempty(imgFiles), return; end
        idx = src.Value;
        loadImageFile(fullfile(dataDir, imgFiles(idx).name), imgFiles(idx).name);
    end

    function onBrowseImage(~, ~)
        [f, p] = uigetfile({'*.jpg;*.png;*.bmp;*.tif', 'File Citra'}, 'Pilih Citra Uji');
        if isequal(f, 0), return; end
        loadImageFile(fullfile(p, f), f);
    end

    function loadImageFile(fullPath, fName)
        state.currentImg  = imread(fullPath);
        state.currentName = fName;
        runSegmentation();
    end

    function onSplitSlider(src, ~)
        val = src.Value;
        edtSplit.String = sprintf('%.3f', val);
        if chkLock.Value == 1
            sldMerge.Value  = val;
            edtMerge.String = sprintf('%.3f', val);
        end
        runSegmentation();
    end

    function onSplitEdit(src, ~)
        val = str2double(src.String);
        if isnan(val), val = sldSplit.Value; end
        val = min(max(val, 0.001), 1.0);
        src.String     = sprintf('%.3f', val);
        sldSplit.Value = min(max(val, sldSplit.Min), sldSplit.Max);
        if chkLock.Value == 1
            sldMerge.Value  = sldSplit.Value;
            edtMerge.String = sprintf('%.3f', val);
        end
        runSegmentation();
    end

    function onMergeSlider(src, ~)
        val = src.Value;
        edtMerge.String = sprintf('%.3f', val);
        if chkLock.Value == 1
            sldSplit.Value  = val;
            edtSplit.String = sprintf('%.3f', val);
        end
        runSegmentation();
    end

    function onMergeEdit(src, ~)
        val = str2double(src.String);
        if isnan(val), val = sldMerge.Value; end
        val = min(max(val, 0.001), 1.0);
        src.String     = sprintf('%.3f', val);
        sldMerge.Value = min(max(val, sldMerge.Min), sldMerge.Max);
        if chkLock.Value == 1
            sldSplit.Value  = sldMerge.Value;
            edtSplit.String = sprintf('%.3f', val);
        end
        runSegmentation();
    end

    function onToggleLock(src, ~)
        if src.Value == 1
            val = str2double(edtSplit.String);
            sldMerge.Value  = min(max(val, sldMerge.Min), sldMerge.Max);
            edtMerge.String = sprintf('%.3f', val);
            runSegmentation();
        end
    end

    function runSegmentation()
        if isempty(state.currentImg), return; end

        predItems  = ddPred.String;
        blockItems = ddBlock.String;

        params.SplitThreshold = str2double(edtSplit.String);
        params.MergeThreshold = str2double(edtMerge.String);
        params.MinBlockSize   = str2double(blockItems{ddBlock.Value});
        params.Predicate      = predItems{ddPred.Value};
        params.Normalize      = true;

        txtStatus.String = 'Memproses segmentasi...';
        drawnow;

        [~, ~, info] = splitAndMerge(state.currentImg, params);
        state.lastInfo = info;

        axes(ax1); imshow(state.currentImg);
        title(sprintf('Citra Asli (%s)', state.currentName), 'Interpreter', 'none');

        axes(ax2); imshow(info.splitRGB);
        title(sprintf('After Split (%d region)', info.numSplitRegions));

        axes(ax3); imshow(info.mergeRGB);
        title(sprintf('After Merge (%d region)', info.numMergeRegions));

        axes(ax4); imshow(info.reconstructed);
        title('Rekonstruksi Mean');

        txtStatus.String = sprintf([ ...
            'Citra: %s | Predikat: %s | MinBlock: %d\n' ...
            'Split Thresh: %.3f | Merge Thresh: %.3f\n' ...
            'Hasil: %d region (Split) -> %d region (Merge) | Waktu: %.3f dtk'], ...
            state.currentName, params.Predicate, params.MinBlockSize, ...
            params.SplitThreshold, params.MergeThreshold, ...
            info.numSplitRegions, info.numMergeRegions, info.executionTime);
    end

    function onSaveResult(~, ~)
        if isempty(state.lastInfo), return; end
        if ~exist(outDir, 'dir')
            mkdir(outDir);
        end

        [~, baseName, ext] = fileparts(state.currentName);
        p = state.lastInfo.params;
        outName = sprintf('sm_%s_%s_s%.3f_m%.3f_b%d%s', ...
            baseName, p.Predicate, p.SplitThreshold, p.MergeThreshold, p.MinBlockSize, ext);
        savePath = fullfile(outDir, outName);

        % Render ke figure tersembunyi agar gambar tersimpan bersih tanpa UI kontrol
        exportFig = figure('Visible', 'off', 'Position', [100, 100, 1280, 340]);
        subplot(1, 4, 1); imshow(state.currentImg); title('Citra Asli');
        subplot(1, 4, 2); imshow(state.lastInfo.splitRGB);
        title(sprintf('After Split (%d)', state.lastInfo.numSplitRegions));
        subplot(1, 4, 3); imshow(state.lastInfo.mergeRGB);
        title(sprintf('After Merge (%d)', state.lastInfo.numMergeRegions));
        subplot(1, 4, 4); imshow(state.lastInfo.reconstructed);
        title('Rekonstruksi Mean');

        saveas(exportFig, savePath);
        close(exportFig);

        txtStatus.String = sprintf('Tersimpan bersih ke:\n%s', savePath);
    end
end