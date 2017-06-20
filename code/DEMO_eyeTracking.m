function DEMO_eyeTracking (varargin)

% this is a demo of the whole eyetracking analysis pipeline.
% 
% A sandbox folder named 'eyeTrackingDEMO' will be created on the user's desktop to replicate
% the dropbox environment of the real routine. All data downloaded and
% produced by the routine will live in the sandbox folder, that will grow
% to take 7-8 GB on the hard disk.
% 
% Make sure your machine is configured to work with ToolboxToolbox.
% The function will download an example eye raw video from fig share. Make
% sure you have an active internet connection.
% 
% For a quicker demo, the user has the option to set how many frames of the
% video they wish to process. As default, the routine will process the
% whole video.
% 
% Usage examples
% ==============
% 
% DEMO_eyeTracking
% 
% DEMO_eyeTracking('numberOfFrames', 500)
% 
%% clear workspace
clear
close all
clc

%% set TbTb
tbUse('LiveTrackAnalysisToolbox');

%% Parse the input
p = inputParser;

% optional inputs
defaultNumFrames = inf;
p.addParameter('numberOfFrames', defaultNumFrames, @isnumeric);

%parse
p.parse(varargin{:})

% define variables
numberOfFrames = p.Results.numberOfFrames;

%% set paths and make directories

% create test sandbox on desktop
sandboxDir = '~/Desktop/eyeTrackingDEMO';
if ~exist(sandboxDir,'dir')
    mkdir(sandboxDir)
end

% add standard dropbox params
params.projectFolder = 'TOME_data';
params.outputDir = 'TOME_processing';
params.projectSubfolder = 'session2_spatialStimuli';
params.eyeTrackingDir = 'EyeTracking';

params.subjectName = 'TOME_3020';
params.sessionDate = '050517';
params.runName = 'tfMRI_FLASH_AP_run01';

% create mock TOME folders in sandbox
dataDir = fullfile(sandboxDir,params.projectFolder, params.projectSubfolder, ...
        params.subjectName,params.sessionDate,params.eyeTrackingDir);
if ~exist(dataDir,'dir')
    mkdir(dataDir)
end

processingDir = fullfile(sandboxDir,params.outputDir, params.projectSubfolder, ...
        params.subjectName,params.sessionDate,params.eyeTrackingDir);
if ~exist(processingDir,'dir')
    mkdir(processingDir)
end

% download the test run from figshare
outfileName = fullfile(dataDir,[params.runName '_raw.mov']);
url = 'https://ndownloader.figshare.com/files/8711089?private_link=8279728e507d375541c7';
system (['curl -L ' sprintf(url) ' > ' sprintf(outfileName)])

%% NOTE: RUN PARAMS vs CONTROL PARAMS

% As we move to a more modular code structure, the overuse of a single
% params struct to control every aspect of the analysis might lead to
% errors and confusion, as even the simplest function would receive a
% massive struct as input variable.

% I suggest we keep using the "params strategy" for metadata-kind of
% information (or RUN PARAMS), such as: subject name, session, runName... 

% All tracking parameters (or CONTROL PARAMS) will be fed through an input
% parser into the tracking functions in form of "options" instead. This
% will allow for easier control of each option (manually or via a control
% file), easier default values settings, and it is very much in style with
% matlab's native functions input managment.


%% DEINTERLACE VIDEO

deinterlaceVideo (params, outputPath, 'Mean')


%% build the input video path

% note that this is the default output format for deinterlaced videos.
inputVideo = fullfile(outputPath,params.outputDir, params.projectSubfolder, ...
        params.subjectName,params.sessionDate,params.eyeTrackingDir, ...
        [params.runName '_60hz.avi']);
    

%% prepare the video
disp('Preparing video...')

tic
[grayI] = prepareVideo(inputVideo, 'numberOfFrames',numberOfFrames); %just tracking a small portion for testing
toc

% note: to test on the full video change 1000 to Inf. It won't be possible
% to change the number of frames analyzed in later steps.


%% track the glint
disp('Tracking glint...')

tic
glintFile = fullfile(outputPath,params.outputDir, params.projectSubfolder, ...
        params.subjectName,params.sessionDate,params.eyeTrackingDir, ...
        'glintTEST.mat');
[glint, glintTrackingParams] = trackGlint(grayI, glintFile);
toc


%% make pupil perimeter video
disp('Making pupil perimeter video...')

tic
perimeterVideo = fullfile(outputPath,params.outputDir, params.projectSubfolder, ...
        params.subjectName,params.sessionDate,params.eyeTrackingDir, ...
        'perimeterTEST.avi');
pupilCircleThresh = 0.06; 
pupilEllipseThresh = 0.96;
perimeterParams = extractPupilPerimeter(grayI, perimeterVideo,'pupilCircleThresh', pupilCircleThresh, 'pupilEllipseThresh', pupilEllipseThresh);
toc

%% COMMENTS SO FAR
% 
%  up to this point the routine produces the following output files,
%  necessary for the subsequent steps:
%  1. pupil perimeter video
%  2. glint tracking file (X,Y position frame by frame)
% 
% 
%  The routine also outputs these structs (currently not saved): 
%  1. glintTrackingParams 
%  2. perimeterParams 
%  They include ALL input necessary
%  to replicate the analysis exactly how it was performed the first time
%  around (including the grayI frameseries that originated from prepareVideo).
%  This means that parsing the structs as inputs for the function
%  trackGlint and extractPupilPerimeter respectively will exactly
%  replicate their outputs.
%  The advantage compared to the "params" strategy is again the modularity:
%  only necessary and unambiguous inputs are fed to each step.


%% blink detection
disp('Finding blinks')

tic
% find the blinks
blinkFrames = findBlinks(glintFile);
toc

% show them on the tracked video (this function is for display only)
showBlinks(blinkFrames,grayI)

% note: blinkFrames is an array containing the index of the frames marked as
% blinks.
%% guess pupil cuts
disp('Computing pupil cuts')

tic
framesToCut = guessPupilCuts(perimeterVideo,glintFile,blinkFrames);
toc

%% make control file
controlFileName = fullfile(outputPath,params.outputDir, params.projectSubfolder, ...
        params.subjectName,params.sessionDate,params.eyeTrackingDir, ...
        'controlFileTEST');

makeControlFile(controlFileName, framesToCut, blinkFrames )

%% main fitting routine

controlFile = [controlFileName '.mat'];
mainPupilRoutine(controlFile,glintFile);
