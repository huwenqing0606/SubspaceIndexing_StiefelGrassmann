%Finding the Euclidean Center of Mass via Gradient Descent on Stiefel Manifolds
%Given objective function f_F(A)=\sum_{k=1}^m \omega_k \|A-A_k\|_F^2 where A, A_k\in St(p, n)
%Use Gradient Descent to find min_A f_F(A)

%author: Wenqing Hu (Missouri S&T)

clearvars;

A = [1 0 0; 0 0 1; 0 1 0; 0 0 0];

omega = [1; 1; 1];
n = size(A, 1);
p = size(A, 2);
Seq = zeros(n, p, 3);
Seq(:, :, 1)=[1 0 0; 0 0 0; 0 1 0; 0 0 1];
Seq(:, :, 2)=[0 1 0; 1 0 0; 0 0 0; 0 0 1];
Seq(:, :, 3)=[0 1 0; 0 0 0; 1 0 0; 0 0 1];

iteration=10000;
lr=0.001;
lrdecayrate=0.5;
gradnormthreshold=0.1;
checkonStiefelthreshold=0.00001;

[fseq, gradfnormseq, distanceseq, minf] = GD_Stiefel(A, omega, Seq, iteration, lr, lrdecayrate, gradnormthreshold, checkonStiefelthreshold);

fprintf("the center is given by the following matrix of size %d times %d\n", n, p);
disp(minf);
[ifStiefel, distance] = CheckOnStiefel(minf, 1);
fprintf("if still on Stiefel= %d, distance to Stiefel= %f\n", ifStiefel, distance);

figure;
plot(fseq, '-.', 'LineWidth', 1, 'MarkerSize', 5, 'MarkerIndices', 1:2:iteration);
hold on;
plot(gradfnormseq, '-*', 'Color', [0.9290 0.6940 0.1250], 'LineWidth', 1, 'MarkerSize', 5, 'MarkerIndices', 1:2:iteration);
plot(distanceseq, '--','Color', [0.6350 0.0780 0.1840],  'LineWidth', 1, 'MarkerSize', 5, 'MarkerIndices', 1:2:iteration);
legend('objective value', 'gradient norm', 'distance to Stiefel');
xlabel('iteration');
ylabel('Objective Value');
hold off;
title('Gradient Descent on Stiefel Manifold');



%gradient descent on Stiefel Manifolds
%Given objective function f_F(A)=\sum_{k=1}^m \omega_k \|A-A_k\|_F^2 where A, A_k\in St(p, n)
%Use Gradient Descent to find min_A f_F(A)
function [fseq, gradfnormseq, distanceseq, minf] = GD_Stiefel(Y, omega, Seq, iteration, lr, lrdecayrate, gradnormthreshold, checkonStiefelthreshold)
    fseq = zeros(iteration, 1);
    gradfnormseq = zeros(iteration, 1);
    distanceseq = zeros(iteration, 1);
    A = Y;
    for i = 1:iteration
        A_previous = A;
        [f, gradf] = gradientStiefel(A, omega, Seq);
        fseq(i) = f;
        gradfnormseq(i) = norm(gradf, 'fro');
        H = lr * (-1) * gradf;
        [M, N, Q] = ExpStiefel(A, H);
        A = A * M + Q * N;        
        [ifStiefel, distanceseq(i)] = CheckOnStiefel(A, checkonStiefelthreshold);
        if ~ifStiefel
            Z = A - A_previous;
            prj_tg = projection_tangent(A_previous, Z);
            [M, N, Q] = ExpStiefel(A_previous, prj_tg);
            A = A_previous * M + Q * N;
        end
        fprintf("iteration %d, value= %f, gradnorm= %f\n", i, f, norm(gradf, 'fro'));
    end
    minf = A;
end

%test if the given matrix Y is on the Stiefel manifold St(p, n)
%Y is the matrix to be tested, threshold is a threshold value, if \|Y^TY-I_p\|_F < threshold then return true
function [ifStiefel, distance] = CheckOnStiefel(Y, threshold)
    n = size(Y, 1);
    p = size(Y, 2);
    Mtx = Y'*Y - eye(p);
    distance = norm(Mtx, 'fro');
    if distance <= threshold
        ifStiefel = true;
    else
        ifStiefel = false;
    end
end


%test if the given matrix H is on the tangent space of Stiefel manifold T_Y St(p, n)
%H is the matrix to be tested, threshold is a threshold value, if \|Y^TH+H^TY\| < threshold then return true
function [ifTangentStiefel] = CheckTangentStiefel(Y, H, threshold)
    n = size(Y, 1);
    p = size(Y, 2);
    n_H = size(H, 1);
    p_H = size(H, 2);
    if (n == n_H) && (p == p_H)
        Mtx = Y' * H + H' * Y;
        distance = norm(Mtx + Mtx', 'fro');
        if distance <= threshold
            ifTangentStiefel = true;
        else
            ifTangentStiefel = false;
        end
    else
        ifTangentStiefel = false;
    end
end


%Exponential Map on Stiefel manifold St(p, n)
%Y is the matrix on St(p, n) and H is the tangent vector
%returns M, N, Q and exp_Y(H)=YM+QN
function [M, N, Q] = ExpStiefel(Y, H)
    n = size(Y, 1);
    p = size(Y, 2);
    W = (eye(n) - Y*Y') * H;
    [Q, R] = qr(W);
    Q = Q(:, 1:p);
    R = R(1:p, :);
    O = zeros(p, p);
    Mtx = [Y'*H -R'; R O];
    Exponential = expm(Mtx);
    i = [eye(p); zeros(p, p)];
    Multiply = Exponential*i;
    M = Multiply(1:p, :);
    N = Multiply(p+1:2*p, :);
end


%calculate the function value and the gradient on Stiefel manifold St(p, n) of the Euclidean center of mass function 
%f_F(A)=\sum_{k=1}^m w_k \|A-A_k\|_F^2
function [f, gradf] = gradientStiefel(Y, omega, Seq)
    m = length(omega);
    f = 0;
    for i = 1:m
        f = f + omega(i)*(norm(Y-Seq(:,:,i), 'fro')^2);
    end
    gradf = 0;
    for i = 1:m
        gradf = gradf + 2*omega(i)*((Y-Seq(:,:,i))-Y*(Y-Seq(:,:,i))'*Y);
    end
end

%calculate the projection onto tangent space of Stiefel manifold St(p, n)
%\Pi_{T, Y}(Z) projects matrix Z of size n by p onto the tangent space of St(p, n) at point Y\in St(p, n)
%returns the tangent vector on T_Y(St(p, n))
function [prj_tg] = projection_tangent(Y, Z)
    n = size(Y, 1);
    p = size(Y, 2);
    skew = (Y' * Z - Z' * Y)/2;
    prj_tg = Y * skew + (eye(n) - Y * Y') * Z;
end


