classdef utility_functions
    
    methods (Static)
        
        % common functions
        function [X_train, X_val, X_test, y_train, y_val, y_test] = train_val_test_split(X, y, val_size, test_size)
            
            if (nargin<3) || (val_size>=1) || (test_size>=1)
                val_size = 0.15;
                test_size = 0.15;
            end
            
            N = length(y);
            shuffle_index = randperm(N);
            X = X(shuffle_index, :);       % shuffle the data
            y = y(shuffle_index, :);       % shuffle the data
            
            val_N = round(N*val_size);
            test_N = round(N*test_size);
            train_index = 1:N-(val_N+test_N);
            val_index = N-(val_N+test_N)+1:N-test_N;
            test_index = N-test_N+1:N;
            
            X_train = X(train_index, :);
            y_train = y(train_index, :);
            X_val = X(val_index, :);
            y_val = y(val_index, :);
            X_test = X(test_index, :);
            y_test = y(test_index, :);
            
        end
        
        % augmenting the input data for convergence of the online model
        function [augmented_x,augmented_y] = augment_data(x, y, augmentation_size)

            if (nargin<3)
                augmentation_size = 150e3;
            end
            
            [N,M] = size(x);
            if N<augmentation_size
                % concat necessary
                concat_time = ceil(augmentation_size/N);
                augmented_x = zeros(concat_time*N, M);
                augmented_y = zeros(concat_time*N, 1);
                for i=1:concat_time
                    start_i = (i-1)*N+1;
                    end_i = i*N;
                    shuffle_i = randperm(length(y));
                    augmented_x(start_i:end_i, :) = x(shuffle_i, :);
                    augmented_y(start_i:end_i, :) = y(shuffle_i, :);
                end
                augmented_x = augmented_x(1:augmentation_size,:);
                augmented_y = augmented_y(1:augmentation_size);
            else
                % no concat
                augmented_x = x;
                augmented_y = y;
            end

        end
        
        % derivative of sigmoid function
        function ret = deriv_sigmoid_loss(z, h)
            sigmoid_loss_x = utility_functions.sigmoid_loss(z, h);
            ret = h*(1-sigmoid_loss_x)*sigmoid_loss_x;
        end

        % sigmoid function
        function ret = sigmoid_loss(z,h)
            ret = 1/(1+exp(-h*z));
        end
        
        % calculate NP score
        function ret = get_NP_score(tpr, fpr, tfpr)
            ret = max(fpr, tfpr)/tfpr-tpr;
        end
        
        % plot_decision_boundaries OLNP
        function plot_decision_boundary(model, x, y)
            
            figure();
            
            w = model.w_;
            b = model.b_;
            tfpr = model.tfpr_;
            P = model.P_;
            E = model.E_;
            connectivity = model.connectivity_;
            sigma_tree = zeros(model.tree_depth_+1,1);
            mu_tree = zeros(model.tree_depth_+1,1);
            y_discriminant = zeros(model.tree_depth_+1,1);
            C = zeros(model.tree_depth_+1,1);
            split_prob = model.split_prob_;
            
            numPtsInGrid = 100;
            x1_min = min(x(:,1));
            x1_max = max(x(:,1));
            x2_min = min(x(:,2));
            x2_max = max(x(:,2));

            % determine space steps
            x1_steps = linspace(x1_min, x1_max, numPtsInGrid);
            x2_steps = linspace(x2_min, x2_max, numPtsInGrid);

            % create the space
            [X1, X2] = meshgrid(x1_steps, x2_steps(end:-1:1));
            Z = zeros(numPtsInGrid, numPtsInGrid);

            for i=1:numPtsInGrid
                for j=1:numPtsInGrid
                    xt = [X1(i,j), X2(i,j)];
                    dark_node_indices = model.find_dark_nodes(xt);
                    for k=1:length(dark_node_indices)
                        dark_node_index = dark_node_indices(k);
                        % calculate sigma
                        if k==1
                            sigma_tree(k) = 1-split_prob;
                        else
                            sigma_tree(k) = (1-split_prob)*P(connectivity(dark_node_index, 2))*sigma_tree(k-1);
                            if k==length(dark_node_indices)
                                sigma_tree(k)=sigma_tree(k)/(1-split_prob);
                            end
                        end
                        % calculate weights
                        mu_tree(k) = sigma_tree(k)*E(dark_node_index)/P(1);
                        if k==length(dark_node_indices)
                            mu_tree(k) = 1-sum(mu_tree(1:k-1));
                        end
                        % calculate discriminant in each node
                        y_discriminant_ = xt*w(:,dark_node_index)+b(dark_node_index);
                        y_discriminant(dark_node_index) = y_discriminant_;
                        C(dark_node_index) = sign(y_discriminant_);
                    end
                    % probabilistic ensemble
                    
                    %yt_predict_index = dark_node_indices(find(rand<cumsum(mu_tree),1,'first'));
                    
                    [~, bb] = max(mu_tree);
                    bb=bb(1);
                    yt_predict_index  = dark_node_indices(bb);
                    
                    yt_predict = C(yt_predict_index);
                    Z(i,j) = yt_predict;
                end
            end

            % store the predictions
            sub_i = randi([1 length(y)], round(length(y)/2), 1);
            y_ = y(sub_i);
            x_ = x(sub_i, :);
            y_pred = zeros(length(y_), 1);
            for i=1:length(y_)
                xt=x_(i,:);
                dark_node_indices = model.find_dark_nodes(xt);
                for k=1:length(dark_node_indices)
                    dark_node_index = dark_node_indices(k);
                    % calculate sigma
                    if k==1
                        sigma_tree(k) = 1-split_prob;
                    else
                        sigma_tree(k) = (1-split_prob)*P(connectivity(dark_node_index, 2))*sigma_tree(k-1);
                        if k==length(dark_node_indices)
                            sigma_tree(k)=sigma_tree(k)/(1-split_prob);
                        end
                    end
                    % calculate weights
                    mu_tree(k) = sigma_tree(k)*E(dark_node_index)/P(1);
                    if k==length(dark_node_indices)
                        mu_tree(k) = 1-sum(mu_tree(1:k-1));
                    end
                    % calculate discriminant in each node
                    y_discriminant_ = xt*w(:,dark_node_index)+b(dark_node_index);
                    y_discriminant(dark_node_index) = y_discriminant_;
                    C(dark_node_index) = sign(y_discriminant_);
                end
                % probabilistic ensemble
%                 yt_predict_index = dark_node_indices(find(rand<cumsum(mu_tree),1,'first'));
                
                [~, bb] = max(mu_tree);
                bb=bb(1);
                yt_predict_index  = dark_node_indices(bb);
                    
                y_pred(i) = C(yt_predict_index);
            end
            
            y_label = cell(length(y_),1);
            y_label(y_<0) = {'Class -1'};
            y_label(y_>0) = {'Class 1'};
            y_label((y_<0) & (y_pred>0)) = {'False alarm'};

            % plot the decision boundary
            % plot the main data
            gscatter(x_(:,1),x_(:,2), y_label, 'brg', 'xo*');
%             xlabel('X_1');
%             ylabel('X_2');
            grid on
            hold on

            % plot the decision boundaries
            hc = [];
            hLegend = findobj(gcf, 'Type', 'Legend');
            set(hc,'EdgeColor','none')
            contour(X1,X2,Z,1,'LineWidth',2,'LineColor','k');
            legend('Location','northeast');
            hold off
            new_legend = hLegend.String;
            new_legend{length(new_legend)} = 'Decision Boundary';
            legend(new_legend);
            title(['Target False Alarm: ', num2str(tfpr)]);
            
        end
        
        % get all parameters and generate hyperparameter space
        % gridsearch cross validation
        function hyperparameter_space = generate_hyperparameter_space_active_Tree_OLNP(parameters)
            
            eta_init_space = parameters.eta_init;
            beta_init_space = parameters.beta_init;
            gamma_space = parameters.gamma;
            sigmoid_h_space = parameters.sigmoid_h;
            lambda_space = parameters.lambda;
            tree_depth_space = parameters.tree_depth;
            split_prob_space = parameters.split_prob;
            node_loss_constant_space = parameters.node_loss_constant;
            entropy_th_space = parameters.entropy_th;
            explore_pr_space = parameters.explore_pr;
            
            n1 = length(eta_init_space);
            n2 = length(beta_init_space);
            n3 = length(gamma_space);
            n4 = length(sigmoid_h_space);
            n5 = length(lambda_space);
            n6 = length(tree_depth_space);
            n7 = length(split_prob_space);
            n8 = length(node_loss_constant_space);
            n9 = length(entropy_th_space);
            n10 = length(explore_pr_space);
            
            % create hyperparameter space
            N = n1*n2*n3*n4*n5*n6*n7*n8*n9*n10;
            hyperparameter_space = cell(N, 1);
            
            % fill the hyperparameter space
            hyper_param_i=1;
            for i_01=1:n1
                for i_02=1:n2
                    for i_03=1:n3
                        for i_04=1:n4
                            for i_05=1:n5
                                for i_06=1:n6
                                    for i_07=1:n7
                                        for i_08=1:n8
                                            for i_09=1:n9
                                                for i_10=1:n10
                                                    hyperparameter_space{hyper_param_i}.eta_init = eta_init_space(i_01);
                                                    hyperparameter_space{hyper_param_i}.beta_init = beta_init_space(i_02);
                                                    hyperparameter_space{hyper_param_i}.gamma = gamma_space(i_03);
                                                    hyperparameter_space{hyper_param_i}.sigmoid_h = sigmoid_h_space(i_04);
                                                    hyperparameter_space{hyper_param_i}.lambda = lambda_space(i_05);
                                                    hyperparameter_space{hyper_param_i}.tree_depth = tree_depth_space(i_06);
                                                    hyperparameter_space{hyper_param_i}.split_prob = split_prob_space(i_07);
                                                    hyperparameter_space{hyper_param_i}.node_loss_constant = node_loss_constant_space(i_08);
                                                    hyperparameter_space{hyper_param_i}.entropy_th = entropy_th_space(i_09);
                                                    hyperparameter_space{hyper_param_i}.explore_pr = explore_pr_space(i_10);
                                                    hyper_param_i = hyper_param_i+1;
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
        end
        
    end
    
end