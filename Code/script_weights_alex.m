%%Script weights
%WKS 
%HKS
%SEGMENT
%WKS + HKS
%WKS + SEGMENT
%HKS + SEGMENT
%WKS + HKS + SEGMENT
% 0.5 WKS + 0.5 HKS + 1 SEGMENT
% 1/6 WKS + 1/6 HKS + 2/3 Segment
clear; 
clc;
init;

Names = ['WKS    ';'HKS    ';'SEGMENT'];
Weights = [1,0,0;0,1,0;0,0,1;1,1,0;1,0,1;0,1,1;1,1,1;0.5,0.5,1;1/6,1/6,2/3];

% for i = 1:size(Weights,1)
%    for j = 1:3
%       if(Weights(i,j))
%          str = [num2str(Weights(i,j)) ' : '  Names(j,:)];
%          disp(str);  
%       end
%    end
%     disp(' ')
% end

testedHorses = [1,5];

for horseNb = 1:size(testedHorses,2)
    %% Setting the name for the horses
    name1 = 'Data/shrec10/0003.null.0.off';
    name2 = ['Data/shrec10/0003.isometry.' num2str(testedHorses(horseNb)) '.off'];
    gtName = ['Data\shrec10gt\0003.isometry.' num2str(testedHorses(horseNb)) '.labels'];
    
    %% Loading the datas
    shape1 = getShape(name1);
    shape2 = getShape(name2);
    gt = load(gtName);
    
    %% Find connected components
    C1 = persistance_based_segmentation(shape1,7);
    shape1.connected_component = C1;
    list_label_C1 = union(C1,C1);


    C2 = persistance_based_segmentation(shape2,7);
    shape2.connected_component = C2;
    list_label_C2 = union(C2,C2);

    list_matching = [];

    list_descriptors_C1 = compute_descriptors_for_matching(shape1);
    list_descriptors_C2 = compute_descriptors_for_matching(shape2);


    %[~,perm1] = sort(list_descriptors_C1);
    %[~,perm2] = sort(list_descriptors_C2);
    nb_comp_C1 = size(list_label_C1,1);
    nb_comp_C2 = size(list_label_C2,1);

    err=[];
    for i=1:nb_comp_C1
        for j=1:nb_comp_C2
            err(i,j) = (list_descriptors_C1(i) - list_descriptors_C2(j))^2./(list_descriptors_C1(i) + list_descriptors_C2(j));
        end
    end
    i = 0;
    INFTY = max(max(err))+1;
    while(i~=min(nb_comp_C1,nb_comp_C2))
        i = i+1;
        [min_per_col,idx_row] = min(err);
        [diff,idx_col] = min(min_per_col);
        list_matching(i,:) = [ list_label_C1(idx_row(idx_col)) list_label_C2(idx_col) diff ];

        % Replace idx_row(idx_col)th row and idx_colth col of err with a high
        % value
        err(idx_row(idx_col),:) = INFTY;
        err(:,idx_col) = INFTY;
    end
    
    %% Create parts indicator functions
    
    shape1.parts = [];
    shape2.parts = [];

    shape1.parts = [shape1.parts 1.*(C1==15346)];
    shape2.parts = [shape2.parts getAssociatedSegmentFromNull(1.*(C1==15346),gt)];
    shape1.parts = [shape1.parts 1.*(C1==11369)];
    shape2.parts = [shape2.parts getAssociatedSegmentFromNull(1.*(C1==11369),gt)];
    shape1.parts = [shape1.parts 1.*(C1==4833)];
    shape2.parts = [shape2.parts getAssociatedSegmentFromNull(1.*(C1==4833),gt)];
    
    %% More functions and weight definition
    
    for weightIndex = 1:size(Weights,1)
        shape1.fun_segment = [];
        shape2.fun_segment = [];

        W = zeros(1608,1);
        weightWKS = Weights(weightIndex,1);
        weightHKS = Weights(weightIndex,2);
        weightSegment = Weights(weightIndex,3);
        weightWKSComm = Weights(weightIndex,1);
        weightHKSComm = Weights(weightIndex,2);
        weightSegmentComm = Weights(weightIndex,3);

        j=1;
        for i = 1:size(shape1.WKS,2)
            shape1.fun_segment = [shape1.fun_segment repmat(shape1.WKS(:,i),1,size(shape1.parts,2)) .* shape1.parts];
            for k = 1:size(shape1.parts,2)
                W(j) = weightSegment;
                j = j+1; 
                W(j) = weightSegmentComm;
                j= j+1;
            end

        end
        for i = 1:size(shape1.HKS,2)
            shape1.fun_segment = [shape1.fun_segment repmat(shape1.HKS(:,i),1,size(shape1.parts,2)) .* shape1.parts];
            for k = 1:size(shape1.parts,2)
                W(j) = weightSegment;
                j = j+1; 
                W(j) = weightSegmentComm;
                j= j+1;
            end
        end
        for i = 1:size(shape2.WKS,2)
            shape2.fun_segment = [shape2.fun_segment repmat(shape2.WKS(:,i),1,size(shape2.parts,2)) .* shape2.parts];
        end
        for i = 1:size(shape2.HKS,2)
            shape2.fun_segment = [shape2.fun_segment repmat(shape2.HKS(:,i),1,size(shape2.parts,2)) .* shape2.parts];
        end

        for i = 1:size(shape1.HKS,2)
            W(j) = weightHKS;
            j = j+1;
            W(j) = weightHKSComm;
            j=j+1;
        end

        for i = 1:size(shape1.WKS,2)
            W(j) = weightWKS;
            j = j+1;
            W(j) = weightWKSComm;
            j=j+1;
        end


        shape1.fun = [shape1.fun_segment, shape1.HKS, shape1.WKS];
        shape2.fun = [shape2.fun_segment, shape2.HKS, shape2.WKS];
        
        %% Computation of C
        disp('Computing C');
        C = calcCFromFuncsWeighted(shape1.fun,shape2.fun,diag(W),shape1.phi,shape2.phi,shape1.L,shape2.L);
        disp('Done');
        disp('Refining C');
        refinedC = refinementC(C,shape1,shape2,30);
        disp('Refinement done');
        
        %% Computation of Point to point
        disp('Computing point to point');
        searchIndexParams = struct();
        shape2toShape1 = flann_search(shape1.phi', refinedC'*shape2.phi', 1, searchIndexParams);
        shape1toShape2 = flann_search(shape2.phi',C*shape1.phi',1,searchIndexParams);
        disp('Done computing point to point');
        
        %% Computing error
        
        disp('DO NOT FORGET TO REINTRODUCE PERFORM FAST MARCHING');
        geoError = zeros(19248,1);
        for i = 1:19248
            options.end_points = shape2toShape1(i);
            [D,S,Q] = perform_fast_marching_mesh(shape1.vertex,shape1.faces,gt(i),options);
            %D = ones(1,19248);
            geoError(i) = D(shape2toShape1(i));
        end
        
        errorToCheck = [0:0.01:40]
        correspondancesAtError = zeros(size(errorToCheck),2);
        for j = 0:0.01:40
           ind = int32(1 + j*100);
           correspondancesAtError(ind) = sum(geoError<j);
        end
        infos = ['WKS : ' num2str(Weights(weightIndex,1)) ', HKS : ' num2str(Weights(weightIndex,2))  ', SEGMENT : ' num2str(Weights(weightIndex,3)) ''];
        
        %% Saving stuff
        corrFileName = ['Result_scripts\Weights\horse' num2str(testedHorses(horseNb)) '-correspondancesAtError' num2str(weightIndex) '.mat'];
        infoFileName = ['Result_scripts\Weights\horse' num2str(testedHorses(horseNb)) '-info' num2str(weightIndex) '.mat'];
        
        save(corrFileName,'correspondancesAtError');
        save(infoFileName,'infos');
        
    end
end