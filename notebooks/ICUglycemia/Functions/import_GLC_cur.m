function GlucoseReadingsCurated = import_GLC_cur(workbookFile, sheetName, dataLines)
%IMPORTFILE Import data from a spreadsheet
%
%  GlucoseReadingsCurated = import_GLC_cur(FILE, SHEET, DATALINES) reads
%  from the specified worksheet for the specified row interval(s).
%  Specify DATALINES as a positive scalar integer or a N-by-2 array of
%  positive scalar integers for dis-contiguous row intervals.
%
%  Example:
%  GlucoseReadingsCurated = import_GLC_cur("GlucoseReadingsCurated.xlsx", "GlucoseReadingsCurated", [2, 458085]);
%
%  See also READTABLE.
%
% Auto-generated by MATLAB on 17-Feb-2020 08:42:30

%% Input handling

% If no sheet is specified, read first sheet
if nargin == 1 || isempty(sheetName)
    sheetName = 1;
end

% If row start and end points are not specified, define defaults
if nargin <= 2
    dataLines = [2, 458085];
end

%% Setup the Import Options and import the data
opts = spreadsheetImportOptions("NumVariables", 8);

% Specify sheet and range
opts.Sheet = sheetName;
opts.DataRange = "A" + dataLines(1, 1) + ":H" + dataLines(1, 2);

% Specify column names and types
opts.VariableNames = ["SUBJECT_ID", "HADM_ID", "ICUSTAY_ID", "ICU_ADMISSIONTIME", "ICU_DISCHARGETIME", "GLCTIMER", "GLC", "GLCSOURCE"];
opts.VariableTypes = ["double", "double", "double", "datetime", "datetime", "datetime", "double", "categorical"];

% Specify variable properties
opts = setvaropts(opts, "GLCSOURCE", "EmptyFieldRule", "auto");
opts = setvaropts(opts, "ICU_ADMISSIONTIME", "InputFormat", "");
opts = setvaropts(opts, "ICU_DISCHARGETIME", "InputFormat", "");
opts = setvaropts(opts, "GLCTIMER", "InputFormat", "");

% Import the data
GlucoseReadingsCurated = readtable(workbookFile, opts, "UseExcel", false);

for idx = 2:size(dataLines, 1)
    opts.DataRange = "A" + dataLines(idx, 1) + ":H" + dataLines(idx, 2);
    tb = readtable(workbookFile, opts, "UseExcel", false);
    GlucoseReadingsCurated = [GlucoseReadingsCurated; tb]; %#ok<AGROW>
end

end