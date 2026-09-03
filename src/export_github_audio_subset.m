%% Export the fixed 12-class waveform subset as 12 GitHub-friendly archives
% Speech clips are byte-for-byte copies of the selected Speech Commands
% source WAV files. Silence examples are the exact one-second, 0.10-gain
% background-noise windows used by run_dataset_smoke_test.m. The original
% 105,829-file corpus remains read-only outside the repository.

clear; clc;

cfg.fs = 16000;
cfg.clipSamples = 16000;
cfg.labels = ["down","go","left","no","off","on", ...
    "right","stop","up","yes","_unknown_","_silence_"];
cfg.archiveNames = ["01_down.zip","02_go.zip","03_left.zip", ...
    "04_no.zip","05_off.zip","06_on.zip","07_right.zip", ...
    "08_stop.zip","09_up.zip","10_yes.zip","11_unknown.zip", ...
    "12_silence.zip"];

scriptPath = string(mfilename("fullpath"));
projectRoot = fileparts(fileparts(scriptPath));
manifestPath = fullfile(projectRoot,"results","sample_manifest.csv");
splitAuditPath = fullfile(projectRoot,"results","split_audit.csv");
localPathFile = fullfile(projectRoot,"data","local_dataset_path.txt");
overrideRoot = string(getenv("ELEC5305_SPEECH_COMMANDS_ROOT"));
if strlength(overrideRoot)>0
    datasetRoot = overrideRoot;
elseif isfile(localPathFile)
    datasetRoot = strtrim(string(fileread(localPathFile)));
else
    datasetRoot = fullfile(projectRoot,"data","speech_commands_v0.02");
end

assert(isfolder(datasetRoot),"Dataset folder not found: %s",datasetRoot);
assert(isfile(fullfile(datasetRoot,"LICENSE")),"Speech Commands LICENSE is missing.");
assert(isfile(manifestPath),"Run run_dataset_smoke_test.m before exporting the subset.");

manifest = readtable(manifestPath,"TextType","string");
assert(height(manifest)==960,"Expected the fixed 960-row manifest; found %d.",height(manifest));
assert(all(ismember(unique(manifest.Label),cfg.labels)),"Manifest contains an unexpected class.");

outputRoot = fullfile(projectRoot,"data","github_subset");
archiveDir = fullfile(outputRoot,"archives");
tmpBase = fullfile(projectRoot,"tmp");
if ~isfolder(outputRoot), mkdir(outputRoot); end
if ~isfolder(archiveDir), mkdir(archiveDir); end
if ~isfolder(tmpBase), mkdir(tmpBase); end
stagingRoot = string(tempname(tmpBase));
mkdir(stagingRoot);
cleanup = onCleanup(@()safe_remove_staging(stagingRoot,tmpBase)); %#ok<NASGU>

licenseTarget = fullfile(outputRoot,"LICENSE_CC_BY_4.0.txt");
copyfile(fullfile(datasetRoot,"LICENSE"),licenseTarget);

rows = cell(height(manifest),13);
rowIndex = 0;
summaryRows = cell(numel(cfg.labels),7);
shaLines = strings(numel(cfg.labels),1);

fprintf("ELEC5305_GITHUB_AUDIO_SUBSET_EXPORT\n");
fprintf("DATASET_ROOT=%s\n",datasetRoot);
for c=1:numel(cfg.labels)
    label = cfg.labels(c);
    classRows = manifest(manifest.Label==label,:);
    assert(sum(classRows.Split=="train")==60 && sum(classRows.Split=="test")==20, ...
        "%s does not have the expected 60/20 split.",label);
    classStage = fullfile(stagingRoot,label);
    mkdir(fullfile(classStage,"train"));
    mkdir(fullfile(classStage,"test"));

    attributionPath = fullfile(classStage,"ATTRIBUTION.txt");
    fid = fopen(attributionPath,"w");
    assert(fid>=0,"Cannot create attribution file.");
    fprintf(fid,"Speech Commands Data Set v0.02 subset\n");
    fprintf(fid,"Original dataset: http://download.tensorflow.org/data/speech_commands_v0.02.tar.gz\n");
    fprintf(fid,"Citation: P. Warden, Speech Commands, arXiv:1804.03209 (2018).\n");
    fprintf(fid,"License: Creative Commons Attribution 4.0 International (CC BY 4.0).\n");
    fprintf(fid,"Project selection: 60 train + 20 test examples for class %s.\n",label);
    if label=="_silence_"
        fprintf(fid,"Modification: one-second background-noise windows were extracted and scaled by 0.10.\n");
    else
        fprintf(fid,"Modification: files were selected; waveform bytes are otherwise unchanged.\n");
    end
    fclose(fid);

    for j=1:height(classRows)
        rowIndex = rowIndex+1;
        split = classRows.Split(j);
        sourceRelative = classRows.DatasetRelativeFile(j);
        sourcePath = fullfile(datasetRoot,replace(sourceRelative,"/",filesep));
        [~,sourceBase,sourceExt] = fileparts(sourcePath);
        if label=="_unknown_"
            exportName = classRows.SourceLabel(j)+"__"+sourceBase+sourceExt;
        elseif label=="_silence_"
            exportName = "noise__"+sourceBase+"__offset_"+string(classRows.OffsetSamples(j))+".wav";
        else
            exportName = sourceBase+sourceExt;
        end
        exportPath = fullfile(classStage,split,exportName);
        isSourceByteCopy = classRows.Kind(j)=="file";
        if isSourceByteCopy
            copyfile(sourcePath,exportPath);
        else
            first = double(classRows.OffsetSamples(j))+1;
            last = first+cfg.clipSamples-1;
            [x,fs] = audioread(sourcePath,[first last]);
            if size(x,2)>1, x=mean(x,2); end
            if fs~=cfg.fs, x=resample(x,cfg.fs,fs); fs=cfg.fs; end
            if numel(x)<cfg.clipSamples, x(end+1:cfg.clipSamples,1)=0;
            elseif numel(x)>cfg.clipSamples, x=x(1:cfg.clipSamples); end
            audiowrite(exportPath,0.10*x,fs,"BitsPerSample",16);
        end
        info = audioinfo(exportPath);
        assert(info.SampleRate==cfg.fs,"Unexpected sample rate in %s",exportPath);
        assert(info.NumChannels==1,"Unexpected channel count in %s",exportPath);
        archiveMember = replace(string(fullfile(label,split,exportName)),filesep,"/");
        rows(rowIndex,:) = {label,split,cfg.archiveNames(c),archiveMember, ...
            classRows.SourceLabel(j),sourceRelative,double(classRows.OffsetSamples(j)), ...
            classRows.Kind(j),isSourceByteCopy,info.SampleRate,info.NumChannels, ...
            info.TotalSamples,sha256_file(exportPath)};
    end

    archivePath = fullfile(archiveDir,cfg.archiveNames(c));
    if isfile(archivePath), delete(archivePath); end
    zip(archivePath,cellstr(label),stagingRoot);
    archiveInfo = dir(archivePath);
    archiveSha = sha256_file(archivePath);
    summaryRows(c,:) = {label,60,20,80,cfg.archiveNames(c),archiveInfo.bytes,archiveSha};
    shaLines(c) = upper(archiveSha)+" *"+cfg.archiveNames(c);
    fprintf("CLASS=%s TRAIN=60 TEST=20 ARCHIVE=%s BYTES=%d\n", ...
        label,cfg.archiveNames(c),archiveInfo.bytes);
end

exportManifest = cell2table(rows,'VariableNames',{'Label','Split','Archive', ...
    'ArchiveMember','SourceLabel','SourceRelativeFile','OffsetSamples','Kind', ...
    'IsSourceByteCopy','SampleRate','Channels','Samples','SHA256'});
summary = cell2table(summaryRows,'VariableNames',{'Label','TrainCount','TestCount', ...
    'TotalCount','Archive','ArchiveBytes','ArchiveSHA256'});
writetable(exportManifest,fullfile(outputRoot,"manifest.csv"));
writetable(summary,fullfile(outputRoot,"class_summary.csv"));
writelines(shaLines,fullfile(outputRoot,"SHA256SUMS.txt"));

splitAudit = readtable(splitAuditPath);
speakerOverlap = sum(splitAudit.InTrain & splitAudit.InTest);
archiveCount = numel(dir(fullfile(archiveDir,"*.zip")));
totalArchiveBytes = sum(summary.ArchiveBytes);
exportPass = height(exportManifest)==960 && archiveCount==12 && ...
    all(summary.TotalCount==80) && speakerOverlap==0 && isfile(licenseTarget);

resultPath = fullfile(projectRoot,"results","DATASET_EXPORT_RESULTS.txt");
fid=fopen(resultPath,"w");
fprintf(fid,"ELEC5305_GITHUB_AUDIO_SUBSET_EXPORT\n");
fprintf(fid,"dataset=Speech Commands v0.02\nlicense=CC BY 4.0\n");
fprintf(fid,"classes=%d\nsamples=%d\ntrain_samples=%d\ntest_samples=%d\n", ...
    numel(cfg.labels),height(exportManifest),sum(exportManifest.Split=="train"),sum(exportManifest.Split=="test"));
fprintf(fid,"archive_count=%d\ntotal_archive_bytes=%d\nmax_archive_bytes=%d\n", ...
    archiveCount,totalArchiveBytes,max(summary.ArchiveBytes));
fprintf(fid,"speaker_overlap_count=%d\nlicense_present=%d\n",speakerOverlap,isfile(licenseTarget));
fprintf(fid,"DATASET_EXPORT_PASS=%d\n",exportPass);
fclose(fid);

disp(summary(:,{'Label','TrainCount','TestCount','Archive','ArchiveBytes'}));
fprintf("TOTAL_ARCHIVE_BYTES=%d\n",totalArchiveBytes);
fprintf("DATASET_EXPORT_PASS=%d\n",exportPass);
assert(exportPass,"Dataset export did not satisfy its declared gates.");

function hex=sha256_file(path)
fid=fopen(path,"rb");
assert(fid>=0,"Cannot hash %s",path);
bytes=fread(fid,Inf,"*uint8");
fclose(fid);
md=java.security.MessageDigest.getInstance("SHA-256");
md.update(typecast(bytes,"int8"));
digest=typecast(md.digest(),"uint8");
hex=lower(string(reshape(dec2hex(digest,2).',1,[])));
end

function safe_remove_staging(stagingRoot,tmpBase)
stagingRoot=string(stagingRoot); tmpBase=string(tmpBase);
assert(startsWith(stagingRoot,tmpBase+filesep),"Refusing to remove staging outside project tmp.");
if isfolder(stagingRoot), rmdir(stagingRoot,"s"); end
end
