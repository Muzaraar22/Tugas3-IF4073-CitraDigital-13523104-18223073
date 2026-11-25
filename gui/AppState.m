classdef AppState < handle
% AppState - wadah state dan komponen untuk SegmentationApp

    properties
        % ---- state aplikasi ----
        RootFolder = '';    % folder repo (tempat SegmentationApp.m)
        DatasetIdx = [];    % struktur dataset dari datasetIndex()
        Original   = [];    % citra masukan (uint8, tidak diubah)
        FileName   = '';    % nama file citra masukan
        Result     = [];    % keluaran applySegmentationMethod ([] = belum diproses)
        Method     = '';    % metode yang menghasilkan Result

        % ---- container utama ----
        Figure     = [];
    end

    properties
        % ---- panel kiri: pilih citra & metode ----
        SourceBox  = []; ImageBox = []; InfoLabel = [];
        MethodBox  = [];
        ParamStack = [];
        Panels     = [];    % struct: .edge .splitmerge .semantic
        SaveButton = [];

        % panel deteksi tepi
        EdgeOperator = []; EdgeSigma = []; EdgeLogSigma = [];
        EdgeThrMode  = []; EdgePercentile = []; EdgeT = [];
        EdgeMinLength = []; EdgeCloseR = []; EdgeMaxCloseR = [];

        % panel split and merge
        SmPredicate = []; SmSplitT = []; SmMergeT = []; SmMinBlock = [];

        % panel semantik
        SemPython = []; SemModel = [];

        % ---- panel kanan ----
        TabGroup  = []; ResultTab = []; StepsTab = [];
        ViewPanels = []; ViewAxes = [];   % 4 panel tab Hasil
        StepPanels = []; StepAxes = [];   % 8 panel tab Tahapan Tepi
        LogText   = [];
    end
end
