%% Function that returns disparity Disparity Maps
% Output :  DispMap (Disparity without sub pixel estimation)
%           Rotation matrix
%           Translation vector in meter
%           DispMap1 (Disparity with sub pixel estimation)
%           DispMap_norm ( Disparity normalized to 0-255).
% Input:    left : left image
%           right : right image
%           BlockSize : Size of the blocks image is partitioned in
%           halfTemplateSize : 2*halfTemplateSize+1 is the number of blocks
%           in the template used for matching
%           K : K-Matrix from calib.txt
%           baseline: distance from cameras from calib.txt
%           SAD : if 1, use SAD, if 0 use NCC

function [R, T,DispMap_norm]=main(left, right, K,BlockSize, halfTemplateSize, baseline, median_filter_on,SAD, d_min, disparityRange,calc_disprange)
    global gui_waitbar_handle;
    global gui_waitbar_text_handle;
    global gui_waitbar_perc_handle;
    T(1) =0;
    count = 0;
    while (T(1)>-0.9 && count<10)
        %% Search features
        Merkmale1 = harris_detektor(left,'segment_length',3,'k',0.04,'min_dist',10,'N',80,'do_plot',false);
        Merkmale2 = harris_detektor(right,'segment_length',3,'k',0.04,'min_dist',10,'N',80,'do_plot',false);

    %% Search Corresponding pairs
        Korrespondenzen = punkt_korrespondenzen(left,right,Merkmale1,Merkmale2,'window_length',25,'min_corr', 0.9);
        [Korrespondenzen_robust] = F_ransac(Korrespondenzen, 'tolerance', 0.04);
    %% Calculate T and R
        E = achtpunktalgorithmus(Korrespondenzen_robust, K);
        [T1, R1, T2, R2] = TR_aus_E(E);
        [T, R, lambda, P1] = rekonstruktion(T1, T2, R1, R2, Korrespondenzen_robust, K);
        count = count+1;
    end
    %% Normalize T to baseline
    T = (T/max(abs(T))*(baseline*10^-3));     
    %% Find min and max disparity range
    if calc_disprange==1
        Matrix(1,:) = Korrespondenzen_robust(1,:);
        Matrix(2,:) = Korrespondenzen_robust(2,:);
        Matrix1(1,:) = Korrespondenzen_robust(3,:);
        Matrix1(2,:) = Korrespondenzen_robust(4,:);
        dist = (Matrix-Matrix1).^2;
        dist = sqrt(dist(1,:) + dist(2,:));
        dist = sort(dist);
    
        d_min = min(dist);
%         disparityRange = (dist(end)+dist(end-1)+dist(end-2)+dist(end-3))/4;
        disparityRange = dist(end);
    end
        
    
   fprintf('Disparity map calculation started\n');
   %% If not started from GUI, create waitbar.
    if isempty(gui_waitbar_handle)
        dis_waitbar = waitbar(0, 'Performing Block Matching, Progress:');
        set(gui_waitbar_handle, 'XData', [0 0 0 0]);
        set(gui_waitbar_perc_handle, 'String', '0.0 %');
        drawnow;
    else
        set(gui_waitbar_text_handle, 'String', 'Performing Block Matching:');
    end
    %% Allocate Space
    DispMap = zeros(size(left), 'single');
    DispMap1 = DispMap;
    diff_Block = zeros(ceil(disparityRange/BlockSize),1);
    %% Get the image dimensions.
    [imgHeight, imgWidth] = size(left);
    %% Add zero frame depending on TemplateSize
    right_frame = zeros(imgHeight+2*halfTemplateSize*BlockSize, imgWidth+2*halfTemplateSize*BlockSize);
    left_frame = right_frame;
    %% Coordinate Origin for picutre without frame
    frame_size_pxl = BlockSize*halfTemplateSize;
    x_no_frame = 1+frame_size_pxl;
    y_no_frame = 1+frame_size_pxl;
    %% Convert to double and insert original pics in the array with zero frame
    right_frame(y_no_frame:y_no_frame+imgHeight-1,x_no_frame:x_no_frame+imgWidth-1) = double(right);
    left_frame(y_no_frame:y_no_frame+imgHeight-1,x_no_frame:x_no_frame+imgWidth-1) = double(left);
    %% Compute N for NCC
    N = BlockSize*((2*halfTemplateSize+1))^2;
    for m = y_no_frame:BlockSize:ceil(y_no_frame+imgHeight-1) % Run through imgHeights/Blocksize rows

        for n = x_no_frame:BlockSize:x_no_frame+(imgWidth-BlockSize) % Run through imgWidth/Blocksize cols
            template = right_frame(m-frame_size_pxl:m+frame_size_pxl+BlockSize-1, n-frame_size_pxl:n+frame_size_pxl+BlockSize-1);
            index_diff_Block = 1;
            %% If SAD selected
            if SAD
                %% If not too far to the right
                if n < imgWidth-disparityRange
                    for i = n:2:n+disparityRange
                        compare_Block = left_frame(m-frame_size_pxl:m+frame_size_pxl+BlockSize-1,i-frame_size_pxl:i+frame_size_pxl+BlockSize-1);
                        if sum(compare_Block(:,1)) == 0
                            diff_Block(index_diff_Block,1) = inf;
                        else
                            diff_Block(index_diff_Block,1) = sum(sum(abs(template-compare_Block)));
                        end
                        index_diff_Block = index_diff_Block+1;
                    end
                else
                %% If too far to the right, make search space smaller
                    for i = n:2:imgWidth
                        compare_Block = left_frame(m-frame_size_pxl:m+frame_size_pxl+BlockSize-1,i-frame_size_pxl:i+frame_size_pxl+BlockSize-1);
                        if sum(compare_Block(:,1)) == 0
                            diff_Block(index_diff_Block,1) = inf;
                        else
                            diff_Block(index_diff_Block,1) = sum(sum(abs(template-compare_Block)));
                        end
                        index_diff_Block = index_diff_Block+1;
                    end
                end
                [~,sortedIndexes] = sort(diff_Block);
                bestMatchIndex = sortedIndexes(1,1);
                d = bestMatchIndex*BlockSize -1;
                DispMap(m-frame_size_pxl:m-frame_size_pxl+BlockSize-1,n-frame_size_pxl:n-frame_size_pxl+BlockSize-1)=d;
                if bestMatchIndex == 1 || bestMatchIndex+1 > size(diff_Block,1)
                    DispMap1(m-frame_size_pxl:m-frame_size_pxl+BlockSize-1,n-frame_size_pxl:n-frame_size_pxl+BlockSize-1) = d;
                else
                    C1 = diff_Block(bestMatchIndex - 1);
                    C2 = diff_Block(bestMatchIndex);
                    C3 = diff_Block(bestMatchIndex + 1);
                    %% Subpixel Estimation from Matlab Example
                    DispMap1(m-frame_size_pxl:m-frame_size_pxl+BlockSize,n-frame_size_pxl:n-frame_size_pxl+BlockSize) = d - (0.5 * (C3 - C1) / (C1 - (2*C2) + C3));
                end 
            %% If NCC selected
            else
                 if n < imgWidth-disparityRange
                    for i = n:BlockSize:n+disparityRange
                        compare_Block = left_frame(m-frame_size_pxl:m+frame_size_pxl+BlockSize-1,i-frame_size_pxl:i+frame_size_pxl+BlockSize-1);
                        %% Generate Matrices for W and V
                        W = (template - mean(template,'all'))/std(template,0,'all');
                        V = (compare_Block - mean(compare_Block,'all'))/std(compare_Block,0,'all');
                        %% If compare block still too far to the left
                        if sum(compare_Block(:,1)) == 0
                            diff_Block(index_diff_Block,1) = 0;
                        else
                            diff_Block(index_diff_Block,1) = 1/(N-1) * trace(W'*V);
                        end
                        index_diff_Block = index_diff_Block+1;
                    end
                else
                %% If n bigger than imgwidth-disparity(too far to the right), make search space smaller, max disparity can only be img_width - n
                    for i = n:BlockSize:imgWidth
                        compare_Block = left_frame(m-frame_size_pxl:m+frame_size_pxl+BlockSize-1,i-frame_size_pxl:i+frame_size_pxl+BlockSize-1);
                        %% Generate Matrices for W and V
                        W = (template - mean(template,'all'))/std(template,0,'all');
                        V = (compare_Block - mean(compare_Block,'all'))/std(compare_Block,0,'all');
                        %% If compare block still too far to the left
                        if sum(compare_Block(:,1)) == 0
                            diff_Block(index_diff_Block,1) = 0;
                        else
                            diff_Block(index_diff_Block,1) = 1/(N-1) * trace(W'*V);
                        end
                        index_diff_Block = index_diff_Block+1;
                    end
                end
                
                [~,sortedIndexes] = sort(diff_Block,'descend');
                bestMatchIndex = sortedIndexes(1,1);
                d = (bestMatchIndex-1)*BlockSize;
                if d > d_min
                    DispMap(m-frame_size_pxl:m-frame_size_pxl+BlockSize-1,n-frame_size_pxl:n-frame_size_pxl+BlockSize-1)=d;
                else
                    second_best_disp = sortedIndexes(sortedIndexes > d_min);
                    DispMap(m-frame_size_pxl:m-frame_size_pxl+BlockSize-1,n-frame_size_pxl:n-frame_size_pxl+BlockSize-1)=second_best_disp(1);
                end
                if bestMatchIndex == 1 || bestMatchIndex+1 > size(diff_Block,1)
                    DispMap1(m-frame_size_pxl:m-frame_size_pxl+BlockSize-1,n-frame_size_pxl:n-frame_size_pxl+BlockSize-1) = d;
                else
                    
%                     C1 = diff_Block(bestMatchIndex - 1);
%                     C2 = diff_Block(bestMatchIndex);
%                     C3 = diff_Block(bestMatchIndex + 1);

                    C1 = sortedIndexes(sortedIndexes<d);
                    C3 = sortedIndexes(sortedIndexes>d);                   
                    if size(C1,1) > 0 && size(C3,1) > 0
                        C1 = C1(1);
                        C2 = d;
                        C3 = C3(1);
                        %DispMap1(m-frame_size_pxl:m-frame_size_pxl+BlockSize-1,n-frame_size_pxl:n-frame_size_pxl+BlockSize-1) = d - (0.5 * (C3 - C1) / (C1 - (2*C2) + C3));
                        DispMap1(m-frame_size_pxl:m-frame_size_pxl+BlockSize-1,n-frame_size_pxl:n-frame_size_pxl+BlockSize-1) = (C1+C2+C3)/3;
                    else
                        DispMap1(m-frame_size_pxl:m-frame_size_pxl+BlockSize-1,n-frame_size_pxl:n-frame_size_pxl+BlockSize-1) = d;
                    end
                    %% Subpixel Estimation from Matlab Example
                    
                    
                end
            end
        end
        
        %% Update waitbar
        progress = ((m-y_no_frame) / imgHeight);
        fprintf('  Image row %d / %d (%.0f%%)\n', m-y_no_frame, imgHeight, (progress * 100));
        if ~isempty(gui_waitbar_handle)
            set(gui_waitbar_handle, 'XData', [0 0 progress progress]);
            set(gui_waitbar_perc_handle, 'String', [num2str(progress*100,'%.1f') ' %']);
            drawnow;
        else
            waitbar(progress, dis_waitbar);
        end
    end
        DispMap_norm = normalize_var(DispMap,0,255);
    if median_filter_on
        if size(DispMap,1) > 1000
            N=20;
            M=30;
        else 
            N=6;
            M=12;
        end      
        med_filter(DispMap_norm, N,M);  
    end
        DispMap_norm = uint8(DispMap_norm);
        
    if isempty(gui_waitbar_handle)
        close(dis_waitbar);
    end
end
