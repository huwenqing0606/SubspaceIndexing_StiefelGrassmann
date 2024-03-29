%%%%%%%%%%%%%%%%%%%% SIFT PCA analysis based on Stiefel center of mass calculation %%%%%%%%%%%%%%%%%%%%

%author: Wenqing Hu (Missouri S&T)

clearvars;
clear classes;

%Generate from SIFT data the local frames A_1, ..., A_{2^ht}
%Find their center of mass A in Euclidean norm under weight w_k = exp(-d_k^2) where d_k is the SIFT distance to each cluster's centroid  

%set the A_1,...,A_m on St(p, n) and the weight sequence, m=2^ht
%the partition tree height
ht = 10;
%the sift_sample size
sample_size = 100 * 2^ht;
%the PCA embedding dimension = kd_siftStiefel
kd_siftStiefel = 16;
%select the sift_sample in SIFT dataset that we will be working on
%generate A_1,...,A_m and w_1,...,w_m
[Seq, omega, sift_sample] = SIFT_PCA_traincluster(sample_size, kd_siftStiefel, ht);

%all these frames are on St(n, p), actually n=128 and p=kd_siftStiefel
n = size(Seq, 1);
p = size(Seq, 2);

%Set the Stiefel Optimization object with given threshold parameters
threshold_gradnorm = 1e-4;
threshold_fixedpoint = 1e-4;
threshold_checkonStiefel = 1e-10;
threshold_logStiefel = 1e-4;
threshold_checkonGrassmann = 1e-10;

StiefelOpt = Stiefel_Optimization(omega, Seq, threshold_gradnorm, threshold_fixedpoint, threshold_checkonStiefel, threshold_logStiefel);

GrassmannOpt = Grassmann_Optimization(omega, Seq, threshold_gradnorm, threshold_fixedpoint, threshold_checkonGrassmann);


tic;
%choose an initial frame to start the GD, randomly selected from A_1,...,A_m
%rng(1, 'twister');
m = length(Seq);
init_label = randi(m);
A = Seq(:, :, init_label);

%Set the parameters for GD on Stiefel St(p, n)
iteration = 1000;
lr = 0.01;
lrdecayrate = 1;
[minf1, fseq, gradfnormseq, distanceseq] = StiefelOpt.Center_Mass_GD_Euclid(A, iteration, lr, lrdecayrate);
toc;

%use the direct Stiefel Euclidean center of mass method
tic;
[minf2, minfvalue2, gradminfnorm2] = StiefelOpt.Center_Mass_Euclid;
toc;

doplotGD = 1; %plot the GD or the direct method

if doplotGD

    minf = minf1;
    
    %plot the objective value, gradient norm and distance to St(p, n)
    figure;
    plot(fseq, '-.', 'LineWidth', 1, 'MarkerSize', 5, 'MarkerIndices', 1:2:iteration);
    xlabel('iteration');
    ylabel('Objective Value');
    legend('objective value');
    title('Gradient Descent on Stiefel Manifold');

    figure;
    plot(gradfnormseq, '-*', 'Color', [0.9290 0.6940 0.1250], 'LineWidth', 1, 'MarkerSize', 5, 'MarkerIndices', 1:2:iteration);
    xlabel('iteration');
    ylabel('Gradient Norm');
    legend('gradient norm');
    title('Gradient Descent on Stiefel Manifold');
    
    figure;
    plot(distanceseq, '--','Color', [0.6350 0.0780 0.1840],  'LineWidth', 1, 'MarkerSize', 5, 'MarkerIndices', 1:2:iteration);
    xlabel('iteration');
    ylabel('Distance to Stiefel');
    title('Gradient Descent on Stiefel Manifold');
    legend('distance to Stiefel');

else
    
    minf = minf2;
    
end

doGrassmann = 1;
if doGrassmann
    iteration = 1000;
    [center, gradnormseq, errornormseq, valueseq, distanceseq] = GrassmannOpt.Center_Mass_Arc(A, iteration);
    disp(center);
    toc;
end

%output the center of mass and check if it is still on Stiefel manifold
disp(minf);
[value, grad] = StiefelOpt.Center_Mass_function_gradient_Euclid(minf);
fprintf("the center is given by the above matrix of size %d times %d\n", n, p);
fprintf("the minimal value is given by %f, gradient norm is given by %f10\n", value, norm(grad, 'fro'));
[ifStiefel, distance] = StiefelOpt.CheckOnStiefel(minf);
fprintf("if still on Stiefel= %d, distance to Stiefel= %f\n", ifStiefel, distance);

%Test the PCA spectrum of SIFT projection onto the eigenspace spanned by the center on St(p, n) that we found
%do an initial PCA on sift_samples dataset
[A0, s0, lat0] = pca(sift_sample);
  
figure;
plot(lat0, '-.', 'LineWidth', 1, 'MarkerSize', 5, 'MarkerIndices', 1:2:n);

%project sift_sample onto the center frame on St(p, n)
x_mean = sift_sample * minf;
%analyze the PCA spectrum of the low-dimensional projection
[A_mean, s_mean, lat_mean] = pca(x_mean);
%plot the PCA spectrum for the projection of sift_sample onto x_mean
%figure;
hold on; 
grid on;
%stem(lat_mean, '.'); 
plot(lat_mean, '--','Color', [0.6350 0.0780 0.1840],  'LineWidth', 1, 'MarkerSize', 5, 'MarkerIndices', 1:2:kd_siftStiefel);
%title('sift projected onto mean eigenspaces pca eigenvalues');

%to compare, randomly pick one element in Seq and do projection and PCA spectrum
bm_label = 1;
fprintf("optimization initial frame label= %d, benchmark frame label= %d\n", init_label, bm_label);
    
x_bm = sift_sample * Seq(:, :, bm_label);
%analyze the PCA spectrum of the low-dimensional projection
[A_bm, s_bm, lat_bm] = pca(x_bm);
%plot the PCA spectrum for the projection of sift_sample onto x_mean
%figure;
%hold on; 
%grid on;
plot(lat_bm, '-*', 'Color', [0.9290 0.6940 0.1250], 'LineWidth', 1, 'MarkerSize', 5, 'MarkerIndices', 1:2:kd_siftStiefel);
%stem(lat_bm, '.'); 
title('sift projected onto frames pca eigenvalues');
%title('sift projected onto randomly selected cluster frames pca eigenvalues');
legend('sift original', 'total center', 'random center');
xlabel('dimension');
ylabel('eigenvalues');
hold off;
    
fprintf("percentage PCA energy loss for mean frame = %f %%, for benchmark frame = %f %%\n", (1-sum(lat_mean)/sum(lat0))*100, (1-sum(lat_bm)/sum(lat0))*100);

figure;
hold on; 
grid on;
stem(lat_mean, '.'); 
xlabel('dimension');
ylabel('eigenvalues');
title('sift projected onto the center of mass Stiefel matrix pca eigenvalues');


function [Seq, omega, sift_sample] = SIFT_PCA_traincluster(sample_size, kd_siftStiefel, ht)

%from the SIFT data set train a sequence of frames A_1, ..., A_m on St(p, n)
%first train a global SIFT PCA embedding A_0
%then the sequence of frames A_1, ..., A_m corresponds to a partition of the SIFT dataset
%from this partition, calculate the weights w_k=exp(-d_k^2) where d_k is the distance on SIFT dataset from the SIFT mean to the mean at each cluster
%return [A_1, ..., A_m] and [w_1, ..., w_m]

%the kd-partition tree height = ht
%the PCA embedding dimension = kd_siftStiefel
%the sift sample size = sample_size

%load the sift dataset
%structure: 
%         n_mp: [3000 3000 3000 364 400 4005 2550]
%        n_nmp: [29904 29904 29904 3640 4000 48675 25500]
%       mp_fid: [16319×2 double]
%      nmp_fid: [171527×2 double]
%        sifts: [10068850×128 uint8]
%    sift_offs: [1×33590 double]

load ~/文档/work_SubspaceIndexingStiefleGrassmann/Code_Subspace_indexing_Stiefel_Grassman/DATA_cdvs-sift300-dataset.mat sifts

%n_sift is the number of samples in sifts dataset, kd_sift is the original dimension of each sample
%kd_sift=128
[n_sift, kd_sift] = size(sifts);

%randomly pick sample_size samples from sift dataset, for partition purposes
offs = randperm(n_sift); 
offs = offs(1: sample_size);
%form the sift_sample dataset
sift_sample = double(sifts(offs, :));

%find the total mean of sift_sample, set as the ceter point for calculating distances
mean_sift_0 = mean(sift_sample);

%do an initial PCA on sift_samples dataset
[A0, s0, lat0] = pca(sift_sample);

%plot the whole PCA spectrum for sift_samples
doplotPCAspectrum = 0;
if doplotPCAspectrum
    figure;
    hold on; grid on;
    stem(lat0, '.'); 
    xlabel('dimension');
    ylabel('eigenvalues');
    title('sift pca eigenvalues');
end
 

%bulid a kd_siftStiefel-dimensional embedding of sift_samples in x0
x0 = sift_sample * A0(:, 1:kd_siftStiefel);

%from x0, partition into 2^ht leaf nodes, each leaf node can give samples for a local PCA
[indx, leafs]=buildVisualWordList(x0, ht);

%the weight sequence
omega = zeros(length(leafs), 1);

% build PCA Model for each leaf
doBuildSiftModel = 1;
% input: sift, indx, leafs
if doBuildSiftModel
    for k=1:length(leafs)
        %form the sift subsample for the k-th cluster
        sift_k = sift_sample(leafs{k}, :); 
        %find the mean of sift_k, set as the ceter point for the k-th cluster
        mean_sift_k = mean(sift_k);
        %calculate the distance d_k = dist(mean_sift_0, mean_sift_k)
        d_k = norm(mean_sift_0 - mean_sift_k);
        %let omega_k = exp(-d_k) (too close to 0), so need to modify to exp(-0.01*d_k)
        %also try omega_k = exp(-0.0001*d_k^2) and omega_k=1/d_k
        omega(k) = exp(-0.0001 * d_k^2);
        %omega(k) = 1/d_k;
        %omega(k) = exp(-0.01 * d_k);
        %do PCA analysis of sift_k and form the k-th frame A_k
        [A{k}, s, lat] = pca(sift_k);
        Seq(:, :, k) = A{k}(:, 1:kd_siftStiefel); 
    end
end    

end
