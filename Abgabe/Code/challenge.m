%% Computer Vision Challenge 2019

% Existiert die Variable directoryname (GUI-Aufruf) oder nicht (ohne GUI)
if exist('directoryname', 'var')
    selpath = directoryname;
    path_existing = 1;
else
    path_existing = 0;
end

clc
%clear all
close all

% Group number:
group_number = 59;

% Group members:
members = { 'Andreas Gaßner', 'Øivind Harket Bakke', 'Vincent Mayer','Robert Lefringhausen', 'Theophil Spiegeler Castaneda'};

% Email-Address (from Moodle!):
mail = {'andreas.gassner@tum.de','oivind.bakke@tum.de','vincent.mayer@tum.de','robert.lefringhausen@tum.de','ge82bab@mytum.de'};

%% Start timer here
tic

%% Disparity Map
% Specify path to scene folder containing img0 img1 and calib
%% Bilder laden

if path_existing == 0
    selpath = uigetdir(path);
end    
    
[K K1 Image1 Image2 baseline] = load_path(selpath);

IGray1 = rgb_to_gray(Image1);
IGray2 = rgb_to_gray(Image2);

%% Block Matching
DisMap=Disparity_blocks(IGray1, IGray2, 2, 2, 250,'true');
%% Disparity from  features , T in m and R
[ T , R , DisMapFeature ] = DispfromFeatures_TR(IGray1 , IGray2, K, baseline);

% Calculate disparity map and Euclidean motion
% [D, R, T] = disparity_map(scene_path)
D=IGray1;
%% Validation
% Specify path to ground truth disparity map || Not really needed, because ground truth are in the same folder as im0,im1 and calib
 gt_path = selpath; 
%
% Load the ground truth
 G = read_pfm(gt_path+'/disp0.pfm');
% 
% Estimate the quality of the calculated disparity map
 p = validate_dmap(D, G);

%% Stop timer here
elapsed_time = toc;


%% Print Results
fprintf( 'R = %.2f,  T= %.2f,  p= %.2f, Elapsed time= %.2f\n', R,T,p,elapsed_time);
% R, T, p, elapsed_time
save('challenge.mat'); %Für test.m notwendig
run(test); %ruft test.m auf.
delete('challenge.mat'); 

%% Display Disparity
figure
imagesc(D)

